import Foundation

/// 采集管道：变更事件 → 完整采集 → 落盘策略 → 组装 Clip → 存入缓存。
/// 实现 ClipboardChangeHandling，直接交给生命周期管家使用。
public final class ClipCapturePipeline: ClipboardChangeHandling, @unchecked Sendable {
    private let pasteboard: PasteboardReading
    private let store: RecentClipsStore
    private let blobManager: BlobFileManager
    private let lock = NSLock()
    private var suppressionUntil: Date?

    public init(
        pasteboard: PasteboardReading,
        store: RecentClipsStore,
        blobManager: BlobFileManager
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.blobManager = blobManager
    }

    /// 抑制指定时长内的所有剪贴板变化（用于写回剪贴板后的"回声"抑制）。
    /// 期间用户真实的复制也会被忽略——调试阶段可接受，正式版改为内容比对式抑制。
    public func suppressChanges(for duration: TimeInterval) {
        lock.lock()
        suppressionUntil = Date().addingTimeInterval(duration)
        lock.unlock()
    }

    public func clipboardDidChange(changeCount: Int) {
        lock.lock()
        if let until = suppressionUntil {
            if Date() < until {
                lock.unlock()
                return
            }
            suppressionUntil = nil
        }
        lock.unlock()

        let formats = ClipContentCapture.capture(from: pasteboard)
        guard !formats.isEmpty else { return }
        let dispatched = PayloadWritePolicy.apply(to: formats, blobManager: blobManager)
        let clip = Clip(
            primaryType: ClipTypeInference.primaryType(from: dispatched),
            formats: dispatched,
            textPreview: textPreview(from: dispatched)
        )
        store.append(clip)
        Log.info("捕获新条目：\(clip.primaryType.rawValue)（\(dispatched.count) 个格式）", module: .clipboard)
    }

    private func textPreview(from formats: [Format]) -> String? {
        guard let plain = formats.first(where: { $0.type == FormatUTI.plainText }),
              case .inline(let data) = plain.payload
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
