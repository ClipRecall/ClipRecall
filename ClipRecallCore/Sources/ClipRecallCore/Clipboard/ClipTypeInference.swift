import Foundation

/// 基础类型推断：按格式包整体形态推断条目主类型。
/// 优先级：文件 > 图片 > 富文本 > 纯文本。
/// 正式版类型识别（URL / 代码 / 颜色检测）在 T1.4 增强。
public enum ClipTypeInference {
    public static func primaryType(from formats: [Format]) -> ClipType {
        let types = Set(formats.map(\.type))
        if types.contains(FormatUTI.fileURL) { return .file }
        if types.contains(FormatUTI.png) || types.contains(FormatUTI.tiff) { return .image }
        if types.contains(FormatUTI.html) || types.contains(FormatUTI.rtf) { return .richText }
        return .text
    }
}
