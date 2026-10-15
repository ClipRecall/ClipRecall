import AppKit
import ClipRecallCore

/// 写回服务：把条目的格式包写回系统剪贴板。
/// 顺序约定：纯文本第一（接收方 App 优先取纯文本），随后 HTML / RTF、图片、文件。
/// 为 T2.3.2（直接粘贴）与 T2.3.3（纯文本模式）提供统一的写入入口。
struct PastebackService {
    private let pasteboard: PasteboardWriting
    private let blobManager: BlobFileManager

    init(pasteboard: PasteboardWriting, blobManager: BlobFileManager) {
        self.pasteboard = pasteboard
        self.blobManager = blobManager
    }

    /// 写回条目；无可用格式或写回失败返回 false。
    @discardableResult
    func writeBack(_ clip: Clip) -> Bool {
        let items = PasteboardWritePayloads.items(from: clip.formats, blobManager: blobManager)
        guard !items.isEmpty else {
            Log.warning("写回失败：条目无可用格式", module: .app)
            return false
        }
        pasteboard.write(items)
        return true
    }
}
