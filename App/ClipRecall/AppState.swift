import AppKit
import ApplicationServices
import Foundation
import Observation
import ClipRecallCore

/// 界面状态：持有核心服务、历史数据与全部设置。
/// 设置修改统一走 setter 方法（改动即持久化并即时生效）。
@MainActor
@Observable
final class AppState {
    // MARK: 数据

    var clips: [Clip] = []
    var isPaused = false

    // MARK: 设置（只读展示值，修改走 setter）

    var retentionMaxCount = 2000
    var retentionMaxDays = 30
    var maskingEnabled = true
    var maskingRatio = 0.5
    var maskPosition: MaskPosition = .trailing
    var directPasteEnabled = false
    var plainTextPasteMode = false
    var excludedBundleIds: [String] = []

    // MARK: 服务

    let settings: SettingsApplication
    private let pasteboard = NSPasteboardAdapter()
    private let repository = ClipRepository()
    private let blobManager = BlobFileManager()
    private let thumbnailService = ThumbnailService(generator: NSImageThumbnailGenerator())
    let faviconFetcher = FaviconFetcher()
    private let pastebackService: PastebackService
    private let monitor: PasteboardMonitor
    private let lifecycle: ClipboardMonitorLifecycle
    private let pipeline: ClipCapturePipeline
    private let exclusionList = AppExclusionList(defaults: [])
    private let hotkeyManager = HotkeyManager()
    private let directPastePerformer = DirectPastePerformer()

    /// 快捷键触发回调（AppDelegate 注入：切换面板）
    var onHotkeyPressed: (() -> Void)?
    /// 面板打开前的 App（直接粘贴的目标）
    var previousApp: NSRunningApplication?

    init() {
        // 启动即打开数据库（自动建目录、建表、迁移）
        _ = try? DatabaseManager.shared.open()

        // 局部读取保存的设置（init 完成前不能通过 self 访问属性）
        let savedSettings = SettingsApplication()
        settings = savedSettings

        pastebackService = PastebackService(pasteboard: pasteboard, blobManager: blobManager)
        monitor = PasteboardMonitor(pasteboard: pasteboard)
        lifecycle = ClipboardMonitorLifecycle(
            monitor: monitor,
            resumeNotificationNames: [NSWorkspace.didWakeNotification]
        )
        pipeline = ClipCapturePipeline(
            pasteboard: pasteboard,
            storage: repository,
            blobManager: blobManager,
            sourceAppProvider: NSWorkspaceSourceAppProvider(),
            exclusionList: exclusionList,
            maskingRatio: savedSettings.maskingEnabled ? savedSettings.maskingRatio : 0,
            maskPosition: savedSettings.maskPosition
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
        // 快捷键（从设置恢复）
        hotkeyManager.register(savedSettings.hotkeySettings) { [weak self] in
            self?.onHotkeyPressed?()
        }
        // 启动时执行一次保留策略，再从数据库加载历史
        try? repository.enforceRetentionPolicy()

        // 加载设置展示值并应用
        retentionMaxCount = savedSettings.retentionPolicy.maxCount
        retentionMaxDays = savedSettings.retentionPolicy.maxDays
        maskingEnabled = savedSettings.maskingEnabled
        maskingRatio = savedSettings.maskingRatio
        maskPosition = savedSettings.maskPosition
        directPasteEnabled = savedSettings.directPasteEnabled
        plainTextPasteMode = savedSettings.plainTextPasteMode
        excludedBundleIds = Array(savedSettings.excludedBundleIds).sorted()
        repository.setRetentionPolicy(RetentionPolicy(maxCount: retentionMaxCount, maxDays: retentionMaxDays))
        exclusionList.replaceAll(Set(excludedBundleIds))

        reloadClips()
        Log.info("AppState 初始化完成，开始监听剪贴板（基线 \(pasteboard.changeCount)）", module: .app)
    }

    // MARK: 设置 setter（持久化 + 即时生效）

    func setRetention(maxCount: Int, maxDays: Int) {
        retentionMaxCount = maxCount
        retentionMaxDays = maxDays
        settings.retentionPolicy = RetentionPolicy(maxCount: maxCount, maxDays: maxDays)
        repository.setRetentionPolicy(RetentionPolicy(maxCount: maxCount, maxDays: maxDays))
    }

    func setMasking(enabled: Bool, ratio: Double, position: MaskPosition) {
        maskingEnabled = enabled
        maskingRatio = ratio
        maskPosition = position
        settings.maskingEnabled = enabled
        settings.maskingRatio = ratio
        settings.maskPosition = position
        pipeline.updateMasking(ratio: enabled ? ratio : 0, position: position)
    }

    func setDirectPaste(_ enabled: Bool) {
        directPasteEnabled = enabled
        settings.directPasteEnabled = enabled
    }

    func setPlainTextMode(_ enabled: Bool) {
        plainTextPasteMode = enabled
        settings.plainTextPasteMode = enabled
    }

    func setExcludedBundleIds(_ ids: [String]) {
        excludedBundleIds = ids
        exclusionList.replaceAll(Set(ids))
        settings.excludedBundleIds = Set(ids)
    }

    /// 录制新快捷键并重新注册。
    func updateHotkey(_ newSettings: HotkeySettings) {
        settings.hotkeySettings = newSettings
        hotkeyManager.register(newSettings) { [weak self] in
            self?.onHotkeyPressed?()
        }
        Log.info("快捷键已更新", module: .app)
    }

    private func reloadClips() {
        // 调试阶段读取全部历史（虚拟化保证 5000 条也流畅）；正式面板可再定义展示上限
        clips = (try? repository.recent(limit: 5000)) ?? []
        Log.info("调试列表已刷新：\(clips.count) 条", module: .app)
    }

    // MARK: 召回与粘贴

    /// 点击/回车条目：把该条目的格式包写回剪贴板（面板关闭后由 performDirectPasteIfEnabled 决定是否自动粘贴）。
    func copyBack(_ clip: Clip) {
        pastebackService.writeBack(clip, plainTextOnly: plainTextPasteMode)
        // 抑制"回声"：1 秒静默窗，忽略写回引起的所有剪贴板变化
        pipeline.suppressChanges(for: 1.0)
        Log.info("调试列表复制回剪贴板：\(clip.primaryType.rawValue)", module: .app)
    }

    /// 直接粘贴（开关开启时）：激活面板打开前的 App，延迟后直投 Cmd+V 事件。
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

    // MARK: 条目管理

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

    // MARK: 其它

    /// 暂停 / 恢复监听。
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
