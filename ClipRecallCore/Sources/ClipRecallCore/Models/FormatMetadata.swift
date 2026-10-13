/// 格式的补充信息；所有字段可空，不同类型的条目只使用相关字段。
public struct FormatMetadata: Codable, Hashable, Sendable {
    /// 图片像素尺寸
    public var pixelSize: PixelSize?
    /// 文件条目包含的文件数量
    public var fileCount: Int?
    /// 代码条目的语言名，如 "Swift"
    public var codeLanguage: String?

    public init(
        pixelSize: PixelSize? = nil,
        fileCount: Int? = nil,
        codeLanguage: String? = nil
    ) {
        self.pixelSize = pixelSize
        self.fileCount = fileCount
        self.codeLanguage = codeLanguage
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
