import Foundation

/// 一种格式表示：同一内容的多表示之一（镜像系统剪贴板设计，见 architecture 4.2）。
public struct Format: Codable, Hashable, Sendable {
    /// 格式类型（UTI），如 public.utf8-plain-text
    public let type: String
    /// 内容载体：小内容内联、大内容落盘
    public var payload: Payload
    /// 补充信息（图片尺寸 / 文件数量 / 代码语言）
    public var metadata: FormatMetadata
    /// 格式版本号，演进预留
    public let version: Int

    public init(
        type: String,
        payload: Payload,
        metadata: FormatMetadata = FormatMetadata(),
        version: Int = 1
    ) {
        self.type = type
        self.payload = payload
        self.metadata = metadata
        self.version = version
    }

    /// 内容是否内联存储在数据库中
    public var isInline: Bool {
        if case .inline = payload { return true }
        return false
    }

    /// 内容是否落盘存储在 blobs 目录
    public var isFileBacked: Bool {
        if case .file = payload { return true }
        return false
    }
}

/// 内容载体。
public enum Payload: Codable, Hashable, Sendable {
    /// 小内容内联存储（数据库列）
    case inline(Data)
    /// 大内容落盘存储（blobs 目录的相对路径）
    case file(path: String)
}

/// 常用格式类型（UTI）常量表。
/// 供采集代码（T1.2）与粘贴代码（T2.3）引用，避免手拼字符串出错。
public enum FormatUTI {
    public static let plainText = "public.utf8-plain-text"
    public static let html = "public.html"
    public static let rtf = "public.rtf"
    public static let png = "public.png"
    public static let tiff = "public.tiff"
    public static let fileURL = "public.file-url"
}
