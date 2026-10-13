import Foundation

/// 剪贴板写入项：一组类型与数据。
public struct PasteboardWriteItem: Sendable {
    public let type: String
    public let data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

/// 剪贴板写入抽象：核心库不依赖平台剪贴板实现。
public protocol PasteboardWriting: Sendable {
    /// 清空剪贴板并写入多组类型-数据。
    func write(_ items: [PasteboardWriteItem])
}

/// 格式包 → 写入项的转换：内联直接转，落盘内容从存放间读出再转。
public enum PasteboardWritePayloads {
    public static func items(from formats: [Format], blobManager: BlobFileManager) -> [PasteboardWriteItem] {
        formats.compactMap { format in
            switch format.payload {
            case .inline(let data):
                return PasteboardWriteItem(type: format.type, data: data)
            case .file(let path):
                guard let data = try? blobManager.read(relativePath: path) else { return nil }
                return PasteboardWriteItem(type: format.type, data: data)
            }
        }
    }
}
