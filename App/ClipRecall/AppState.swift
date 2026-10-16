import AppKit
import ApplicationServices
import Foundation
import Observation
import ServiceManagement
import ClipRecallCore

/// 界面状态：持有核心服务、历史数据与全部设置。
/// 设置修改统一走 setter 方法（改动即持久化并即时生效）。
@MainActor
@Observable
final class AppState {
    // MARK: 数据

    var clips: [Clip] = []
    var isPaused = false

    // MARK: 搜索与过滤（T3.2.2；修改走 setter 以统一应用查询）

    var searchText = ""
    var typeFilter: ClipType?
    var sourceFilter: String?
    var timeFilter: ClipTimeRange?
    /// 来源 App 下拉数据源（去重、按名称排序）
    var sourceApps: [(bundleId: String, name: String)] = []
    private var searchTask: Task<Void, Never>?

    // MARK: 设置（只读展示值，修改走 setter）

    var retentionMaxCount = 2000
    var retentionMaxDays = 30
    var maskingEnabled = true
    var maskingRatio = 0.5
    var maskPosition: MaskPosition = .trailing
    var directPasteEnabled = false
    var plainTextPasteMode = false
    var excludedBundleIds: [String] = []
    /// 登录时启动开关（以持久化偏好为准；调试构建系统注册可能被回滚，正式签名后稳定）
    var launchAtLogin = false

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
    private let ocrQueue: OCRIndexingQueue

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
        // 增量 OCR 索引队列（启动在 init 末尾，此处仅初始化）
        ocrQueue = OCRIndexingQueue(repository: repository)
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
        // 搜索索引自愈：行数不一致时全量重建（v0.2.0 升级后旧历史补索引走这里）
        if let rebuilt = try? repository.rebuildSearchIndexIfNeeded() {
            if rebuilt {
                Log.info("搜索索引已重建（升级补索引或漂移修复）", module: .app)
            }
        }

        // 加载设置展示值并应用
        retentionMaxCount = savedSettings.retentionPolicy.maxCount
        retentionMaxDays = savedSettings.retentionPolicy.maxDays
        maskingEnabled = savedSettings.maskingEnabled
        maskingRatio = savedSettings.maskingRatio
        maskPosition = savedSettings.maskPosition
        directPasteEnabled = savedSettings.directPasteEnabled
        plainTextPasteMode = savedSettings.plainTextPasteMode
        excludedBundleIds = Array(savedSettings.excludedBundleIds).sorted()
        // 登录启动自愈：偏好开启但系统未注册时补注册
        launchAtLogin = savedSettings.launchAtLogin
        if launchAtLogin, SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }
        repository.setRetentionPolicy(RetentionPolicy(maxCount: retentionMaxCount, maxDays: retentionMaxDays))
        exclusionList.replaceAll(Set(excludedBundleIds))

        reloadClips()
        // 增量 OCR 索引队列启动：后台识别历史/新截图文字（断点续传）
        ocrQueue.start()
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

    /// 切换登录时启动（即时注册/注销 + 持久化偏好）。
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            settings.launchAtLogin = enabled
            Log.info("登录时启动：\(enabled ? "开" : "关")", module: .app)
        } catch {
            Log.error("登录启动设置失败：\(error)", module: .app)
        }
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
        applyQuery()
    }

    /// 按当前搜索词与过滤器查询（无过滤时等价最近列表）；新条目到达/删除/固定后的刷新也走这里，
    /// 保证筛选状态下列表仍符合条件。
    private func applyQuery() {
        clips = (try? repository.fetchClips(
            query: searchText,
            filter: ClipFilter(
                types: typeFilter.map { [$0] },
                sourceAppBundleId: sourceFilter,
                timeRange: timeFilter
            ),
            limit: 5000
        )) ?? []
        sourceApps = (try? repository.fetchSourceApps()) ?? []
        Log.info("调试列表已刷新：\(clips.count) 条", module: .app)
    }

    // MARK: 搜索与过滤 setter（修改即持久查询；搜索词带 250ms 防抖）

    /// 搜索框输入：防抖 250ms，连续输入只查最后一次。
    func setSearchText(_ text: String) {
        searchText = text
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.applyQuery()
        }
    }

    func setTypeFilter(_ type: ClipType?) {
        typeFilter = type
        applyQuery()
    }

    func setSourceFilter(_ bundleId: String?) {
        sourceFilter = bundleId
        applyQuery()
    }

    func setTimeFilter(_ range: ClipTimeRange?) {
        timeFilter = range
        applyQuery()
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
