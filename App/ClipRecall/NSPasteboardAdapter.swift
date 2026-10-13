import AppKit
import ClipRecallCore

/// 系统剪贴板适配器：实现核心库的读写抽象。
struct NSPasteboardAdapter: PasteboardReading, PasteboardWriting, @unchecked Sendable {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int {
        pasteboard.changeCount
    }

    var types: [String] {
        (pasteboard.types ?? []).map(\.rawValue)
    }

    func data(forType type: String) -> Data? {
        pasteboard.data(forType: NSPasteboard.PasteboardType(type))
    }

    func string(forType type: String) -> String? {
        pasteboard.string(forType: NSPasteboard.PasteboardType(type))
    }

    func write(_ items: [PasteboardWriteItem]) {
        pasteboard.clearContents()
        let allTypes = items.map { NSPasteboard.PasteboardType($0.type) }
        pasteboard.declareTypes(allTypes, owner: nil)
        for item in items {
            let pbType = NSPasteboard.PasteboardType(item.type)
            // 文本类与文件清单用字符串写入，其余按原始数据
            if item.type == FormatUTI.plainText || item.type == FormatUTI.fileURL {
                if let string = String(data: item.data, encoding: .utf8) {
                    pasteboard.setString(string, forType: pbType)
                    continue
                }
            }
            pasteboard.setData(item.data, forType: pbType)
        }
    }
}
