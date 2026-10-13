import Foundation

/// 采集管道：变更事件 → 完整采集 → 落盘策略 → 组装 Clip → 存入缓存。
/// 实现 ClipboardChangeHandling，直接交给生命周期管家使用。
public final class ClipCapturePipeline: ClipboardChangeHandling, @unchecked Sendable {
    private let pasteboard: PasteboardReading
    private let store: RecentClipsStore
    private let blobManager: BlobFileManager

    public init(
        pasteboard: PasteboardReading,
        store: RecentClipsStore,
        blobManager: BlobFileManager
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.blobManager = blobManager
    }

    public func clipboardDidChange(changeCount: Int) {
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
