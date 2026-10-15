import Foundation

/// 文本采集器：读取剪贴板上的全部文本形态（纯文本 / HTML / RTF），打包为 Format 格式包。
public enum TextCapture {
    /// 采集顺序：纯文本永远第一（列表预览与搜索索引依赖它）。
    public static let captureOrder: [String] = [FormatUTI.plainText, FormatUTI.html, FormatUTI.rtf]

    /// 从剪贴板读取全部文本表示，返回格式包；没有任何文本形态时返回空数组。
    public static func capture(from pasteboard: PasteboardReading) -> [Format] {
        var formats: [Format] = []
        for type in captureOrder where pasteboard.types.contains(type) {
            let payload: Payload?
            if type == FormatUTI.plainText {
                payload = pasteboard.string(forType: type).map { .inline(Data($0.utf8)) }
            } else {
                payload = pasteboard.data(forType: type).map { .inline($0) }
            }
            if let payload {
                formats.append(Format(type: type, payload: payload))
            }
        }
        return formats
    }
}
