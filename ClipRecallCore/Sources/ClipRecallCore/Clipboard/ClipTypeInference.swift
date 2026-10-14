import Foundation

/// 基础类型推断：按格式包整体形态推断条目主类型。
/// 优先级：文件 > 图片 > 富文本 > 链接 > 纯文本。
/// 正式版类型识别（代码 / 颜色检测）在 T1.4.3 / T1.4.4 增强。
public enum ClipTypeInference {
    public static func primaryType(from formats: [Format]) -> ClipType {
        let types = Set(formats.map(\.type))
        if types.contains(FormatUTI.fileURL) { return .file }
        if types.contains(FormatUTI.png) || types.contains(FormatUTI.tiff) { return .image }
        if types.contains(FormatUTI.html) || types.contains(FormatUTI.rtf) { return .richText }
        if let plainText = plainTextContent(from: formats),
           URLDetection.detect(in: plainText) != nil {
            return .url
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
