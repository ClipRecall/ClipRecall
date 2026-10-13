import AppKit
import Foundation
import Observation
import ClipRecallCore

/// 界面状态：持有核心服务与调试列表数据。
@MainActor
@Observable
final class AppState {
    var clips: [Clip] = []

    private let pasteboard = NSPasteboardAdapter()
    private let store = RecentClipsStore(limit: 50)
    private let blobManager = BlobFileManager()
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
}
