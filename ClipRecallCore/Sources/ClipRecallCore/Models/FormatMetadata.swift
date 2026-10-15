import Foundation

/// 文件引用档案：记录复制时的文件地址、名称与大小（只存引用不存副本）。
public struct FileReference: Codable, Hashable, Sendable {
    /// 文件 URL（file:// 格式）
    public let url: String
    /// 文件名
    public let name: String
    /// 字节大小；目录或文件已不存在时为 nil
    public let size: Int64?

    public init(url: String, name: String, size: Int64?) {
        self.url = url
        self.name = name
        self.size = size
    }
}

/// 格式的补充信息；所有字段可空，不同类型的条目只使用相关字段。
public struct FormatMetadata: Codable, Hashable, Sendable {
    /// 图片像素尺寸
    public var pixelSize: PixelSize?
    /// 文件条目包含的文件数量
    public var fileCount: Int?
    /// 代码条目的语言名，如 "Swift"
    public var codeLanguage: String?
    /// 文件条目的引用档案清单
    public var files: [FileReference]?
    /// 敏感内容类别（卡号 / 密钥），检测到时标注
    public var sensitiveKind: SensitiveKind?

    public init(
        pixelSize: PixelSize? = nil,
        fileCount: Int? = nil,
        codeLanguage: String? = nil,
        files: [FileReference]? = nil,
        sensitiveKind: SensitiveKind? = nil
    ) {
        self.pixelSize = pixelSize
        self.fileCount = fileCount
        self.codeLanguage = codeLanguage
        self.files = files
        self.sensitiveKind = sensitiveKind
    }
}

/// 图片像素尺寸。
/// 不使用系统图形类型（如 CGSize），保持核心库零平台依赖。
public struct PixelSize: Codable, Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
