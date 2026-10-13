/// 剪贴板条目的主类型。
/// 注意：url / code / color 为派生类型——从纯文本检测得出。
/// 原始字符串值用于持久化存储，已发布后不可更改（详见 architecture 4.1）。
public enum ClipType: String, Codable, CaseIterable, Hashable, Sendable {
    /// 纯文本
    case text
    /// 富文本（HTML / RTF）
    case richText
    /// 图片
    case image
    /// 文件（存引用不存副本）
    case file
    /// 网址（派生类型）
    case url
    /// 代码（派生类型）
    case code
    /// 颜色值（派生类型）
    case color
}
