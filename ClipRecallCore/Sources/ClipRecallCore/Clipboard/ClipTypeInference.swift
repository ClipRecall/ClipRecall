import Foundation

/// 基础类型推断：按格式包整体形态推断条目主类型。
/// 优先级：文件 > 图片 > 富文本 > 链接 > 代码 > 纯文本。
/// 颜色检测在 T1.4.4 增强。
public enum ClipTypeInference {
    public static func primaryType(from formats: [Format]) -> ClipType {
        let types = Set(formats.map(\.type))
        if types.contains(FormatUTI.fileURL) { return .file }
        if types.contains(FormatUTI.png) || types.contains(FormatUTI.tiff) { return .image }
        if types.contains(FormatUTI.html) || types.contains(FormatUTI.rtf) { return .richText }
        if let plainText = plainTextContent(from: formats) {
            if URLDetection.detect(in: plainText) != nil { return .url }
            if CodeLanguageDetection.detect(in: plainText) != nil { return .code }
        }
        return .text
    }

    /// 提取首个纯文本格式的字符串内容（仅内联载荷）。
    public static func plainTextContent(from formats: [Format]) -> String? {
        guard let plain = formats.first(where: { $0.type == FormatUTI.plainText }),
              case .inline(let data) = plain.payload,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}
