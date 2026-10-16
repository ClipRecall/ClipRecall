import AppKit
import ApplicationServices
import Foundation
import Observation
import ClipRecallCore

/// 界面状态：持有核心服务与调试列表数据。
@MainActor
@Observable
final class AppState {
    var clips: [Clip] = []
    /// 是否已暂停监听
    var isPaused = false
    /// 直接粘贴开关（默认关 = 进剪贴板手动 Cmd+V；T2.6.2 设置页接管）
    var directPasteEnabled = false
    /// 纯文本粘贴开关（默认关 = 原格式；T2.6.2 设置页接管）
    var plainTextPasteMode = false
    /// 面板打开前的 App（直接粘贴的目标）
    var previousApp: NSRunningApplication?
    private let directPastePerformer = DirectPastePerformer()

    private let pasteboard = NSPasteboardAdapter()
    private let repository = ClipRepository()
    private let blobManager = BlobFileManager()
    private let thumbnailService = ThumbnailService(generator: NSImageThumbnailGenerator())
    let faviconFetcher = FaviconFetcher()
    private let pastebackService: PastebackService
    private let monitor: PasteboardMonitor
    private let lifecycle: ClipboardMonitorLifecycle
    private let pipeline: ClipCapturePipeline

    init() {
        // 启动即打开数据库（自动建目录、建表）；失败不阻塞界面
        _ = try? DatabaseManager.shared.open()
        monitor = PasteboardMonitor(pasteboard: pasteboard)
        lifecycle = ClipboardMonitorLifecycle(
            monitor: monitor,
            resumeNotificationNames: [NSWorkspace.didWakeNotification]
        )
        pastebackService = PastebackService(pasteboard: pasteboard, blobManager: blobManager)
        pipeline = ClipCapturePipeline(
            pasteboard: pasteboard,
            storage: repository,
            blobManager: blobManager,
            sourceAppProvider: NSWorkspaceSourceAppProvider(),
            exclusionList: AppExclusionList()
        )
        repository.onAppend = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reloadClips()
            }
        }
        lifecycle.start(handler: pipeline)
        // 登记启动基线：监听开始前剪贴板上已有的内容永不记录
        let baselineFormats = ClipContentCapture.capture(from: pasteboard)
        pipeline.setBaselineFingerprint(FormatFingerprint.contentIdentity(from: baselineFormats))
        // 启动时执行一次保留策略（如上次会话的测试数据超限，自动清理），再从数据库加载历史
        try? repository.enforceRetentionPolicy()
        reloadClips()
        Log.info("AppState 初始化完成，开始监听剪贴板（基线 \(pasteboard.changeCount)）", module: .app)
    }

    private func reloadClips() {
        // 调试阶段读取全部历史（虚拟化保证 5000 条也流畅）；正式面板可再定义展示上限
        clips = (try? repository.recent(limit: 5000)) ?? []
        Log.info("调试列表已刷新：\(clips.count) 条", module: .app)
    }

    /// 点击/回车条目：把该条目的格式包写回剪贴板（面板关闭后由 performDirectPasteIfEnabled 决定是否自动粘贴）。
    func copyBack(_ clip: Clip) {
        pastebackService.writeBack(clip, plainTextOnly: plainTextPasteMode)
        // 抑制"回声"：1 秒静默窗，忽略写回引起的所有剪贴板变化
        pipeline.suppressChanges(for: 1.0)
        Log.info("调试列表复制回剪贴板：\(clip.primaryType.rawValue)", module: .app)
    }

    /// 直接粘贴（开关开启时）：激活面板打开前的 App，延迟后直投 Cmd+V 事件。
    /// 面板已先关闭——先关面板释放我们的激活，再激活目标、等它就绪，避免事件早到被拒。
    func performDirectPasteIfEnabled() {
        guard directPasteEnabled, let previousApp else { return }
        previousApp.activate()
        let pid = previousApp.processIdentifier
        let appName = previousApp.localizedName ?? "前台 App"
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            directPastePerformer.performPaste(to: pid)
            Log.info("直接粘贴到 \(appName)", module: .app)
        }
    }

    /// 暂停 / 恢复监听。恢复时以当前剪贴板为基线，暂停期间的内容不进历史。
    func togglePause() {
        if isPaused {
            lifecycle.start(handler: pipeline)
            isPaused = false
            Log.info("恢复监听", module: .app)
        } else {
            lifecycle.stop()
            isPaused = true
            Log.info("暂停监听", module: .app)
        }
    }

    /// 取图片条目的原始图片数据（内联或落盘载荷）。
    func imageData(for clip: Clip) -> Data? {
        for format in clip.formats
        where format.type == FormatUTI.png || format.type == FormatUTI.tiff {
            switch format.payload {
            case .inline(let data): return data
            case .file(let path): return try? blobManager.read(relativePath: path)
            }
        }
        return nil
    }

    /// 获取图片条目缩略图（异步，带缓存）。
    func thumbnail(for clip: Clip) async -> Data? {
        guard let data = imageData(for: clip) else { return nil }
        return thumbnailService.thumbnail(for: data)
    }

    /// 固定 / 取消固定。
    func togglePin(_ clip: Clip) {
        var updated = clip
        updated.pinned.toggle()
        do {
            try repository.update(updated)
            reloadClips()
            Log.info("已\(updated.pinned ? "固定" : "取消固定")条目", module: .app)
        } catch {
            Log.error("固定操作失败：\(error)", module: .app)
        }
    }

    /// 删除单条（软删除 tombstone）。
    func deleteClip(_ clip: Clip) {
        do {
            try repository.delete(id: clip.id)
            reloadClips()
            Log.info("已删除条目", module: .app)
        } catch {
            Log.error("删除失败：\(error)", module: .app)
        }
    }

    /// 多选合并复制：按选择顺序拼接纯文本，写回剪贴板（配合直接粘贴开关）。
    func mergeAndCopy(_ clips: [Clip]) {
        guard let text = ClipMerging.mergedText(from: clips) else {
            Log.warning("合并复制失败：所选条目无纯文本", module: .app)
            return
        }
        let merged = Clip(
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
        pastebackService.writeBack(merged, plainTextOnly: plainTextPasteMode)
        pipeline.suppressChanges(for: 1.0)
        performDirectPasteIfEnabled()
        Log.info("已合并复制 \(clips.count) 条", module: .app)
    }

    /// 清空全部历史（硬删除，含落盘文件）。
    func clearAllHistory() {
        do {
            let removed = try repository.clearAll()
            reloadClips()
            Log.info("已清空历史：\(removed) 条", module: .app)
        } catch {
            Log.error("清空失败：\(error)", module: .app)
        }
    }

    /// 辅助功能权限是否已开启（直接粘贴功能需要）。
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// 打开系统设置的辅助功能页面。
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
