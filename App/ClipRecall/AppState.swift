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

    private let pasteboard = NSPasteboardAdapter()
    private let store = RecentClipsStore(limit: 50)
    private let blobManager = BlobFileManager()
    let faviconFetcher = FaviconFetcher()
    private let monitor: PasteboardMonitor
    private let lifecycle: ClipboardMonitorLifecycle
    private let pipeline: ClipCapturePipeline

    init() {
        monitor = PasteboardMonitor(pasteboard: pasteboard)
        lifecycle = ClipboardMonitorLifecycle(
            monitor: monitor,
            resumeNotificationNames: [NSWorkspace.didWakeNotification]
        )
        pipeline = ClipCapturePipeline(
            pasteboard: pasteboard,
            store: store,
            blobManager: blobManager
        )
        store.onAppend = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.clips = self.store.clips
                Log.info("调试列表已刷新：\(self.clips.count) 条", module: .app)
            }
        }
        lifecycle.start(handler: pipeline)
        // 登记启动基线：监听开始前剪贴板上已有的内容永不记录
        let baselineFormats = ClipContentCapture.capture(from: pasteboard)
        pipeline.setBaselineFingerprint(FormatFingerprint.contentIdentity(from: baselineFormats))
        Log.info("AppState 初始化完成，开始监听剪贴板（基线 \(pasteboard.changeCount)）", module: .app)
    }

    /// 点击调试列表条目：把该条目的格式包写回剪贴板。
    func copyBack(_ clip: Clip) {
        let items = PasteboardWritePayloads.items(from: clip.formats, blobManager: blobManager)
        guard !items.isEmpty else { return }
        pasteboard.write(items)
        // 抑制"回声"：1 秒静默窗，忽略写回引起的所有剪贴板变化
        pipeline.suppressChanges(for: 1.0)
        Log.info("调试列表复制回剪贴板：\(clip.primaryType.rawValue)", module: .app)
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
