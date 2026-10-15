import Foundation

/// 基础类型推断：按格式包整体形态推断条目主类型。
/// 优先级：文件 > 图片 > 纯文本派生（颜色 > 邮箱 > 链接 > 代码 > 日期）> 富文本 > 纯文本。
/// 纯文本派生先于富文本："是什么"比"带不带格式"更重要——带 HTML 的颜色值仍是颜色值。
public enum ClipTypeInference {
    public static func primaryType(from formats: [Format]) -> ClipType {
        let types = Set(formats.map(\.type))
        if types.contains(FormatUTI.fileURL) { return .file }
        if types.contains(FormatUTI.png) || types.contains(FormatUTI.tiff) { return .image }
        if let plainText = plainTextContent(from: formats) {
            if ColorDetection.detect(in: plainText) != nil { return .color }
            // 邮箱先于 URL 检测：foo@bar.com 会被 URL 误判为网址
            if EmailDetection.detect(in: plainText) != nil { return .text }
            if URLDetection.detect(in: plainText) != nil { return .url }
            if CodeLanguageDetection.detect(in: plainText) != nil { return .code }
            if DateDetection.detect(in: plainText) != nil { return .text }
        }
        if types.contains(FormatUTI.html) || types.contains(FormatUTI.rtf) { return .richText }
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
