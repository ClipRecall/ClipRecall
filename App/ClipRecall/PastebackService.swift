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

    /// 写回条目；plainTextOnly 时仅保留纯文本格式（剥离富文本）。
    /// 无纯文本的条目（图片/文件）按原样写回——"纯文本"对它们无意义。
    @discardableResult
    func writeBack(_ clip: Clip, plainTextOnly: Bool = false) -> Bool {
        var items = PasteboardWritePayloads.items(from: clip.formats, blobManager: blobManager)
        if plainTextOnly {
            let plainItems = items.filter { $0.type == FormatUTI.plainText }
            if !plainItems.isEmpty {
                items = plainItems
            }
        }
        guard !items.isEmpty else {
            Log.warning("写回失败：条目无可用格式", module: .app)
            return false
        }
        pasteboard.write(items)
        return true
    }
}
