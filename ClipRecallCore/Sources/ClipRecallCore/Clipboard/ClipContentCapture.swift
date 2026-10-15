import Foundation

/// 剪贴板内容统一采集：组装完整格式包（文本 → 图片 → 文件）。
/// 这是"记录历史"的唯一采集入口——任何形态都不会被落下，格式保真的兜底机制。
public enum ClipContentCapture {
    public static func capture(from pasteboard: PasteboardReading) -> [Format] {
        TextCapture.capture(from: pasteboard)
            + ImageCapture.capture(from: pasteboard)
            + FileCapture.capture(from: pasteboard)
    }
}

public extension Array where Element == Format {
    /// 是否含富文本形态（HTML / RTF）——"原格式粘贴"是否可用的判断依据。
    var containsRichText: Bool {
        contains { $0.type == FormatUTI.html || $0.type == FormatUTI.rtf }
    }
}
