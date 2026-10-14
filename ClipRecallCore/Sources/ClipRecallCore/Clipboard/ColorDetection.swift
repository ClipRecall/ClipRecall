import Foundation

/// 颜色识别结果。
public struct ColorInfo: Equatable, Sendable {
    /// 规范化十六进制（#RRGGBB）
    public let hex: String
    public let red: Int
    public let green: Int
    public let blue: Int
}

/// 颜色检测：整段文本是十六进制颜色值时识别（#RGB / #RRGGBB）。
public enum ColorDetection {
    public static func detect(in text: String) -> ColorInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expanded = expandIfShort(trimmed),
              let red = hexPair(expanded, at: 1),
              let green = hexPair(expanded, at: 3),
              let blue = hexPair(expanded, at: 5)
        else { return nil }
        return ColorInfo(hex: expanded, red: red, green: green, blue: blue)
    }

    /// 规范化：#RGB → #RRGGBB；#RRGGBB 原样大写；其他返回 nil。
    private static func expandIfShort(_ text: String) -> String? {
        let hexDigits = "0123456789abcdefABCDEF"
        if text.count == 7, text.hasPrefix("#"), text.dropFirst().allSatisfy({ hexDigits.contains($0) }) {
            return text.uppercased()
        }
        if text.count == 4, text.hasPrefix("#"), text.dropFirst().allSatisfy({ hexDigits.contains($0) }) {
            let expanded = text.dropFirst().flatMap { [$0, $0] }
            return "#" + String(expanded).uppercased()
        }
        return nil
    }

    private static func hexPair(_ hex: String, at offset: Int) -> Int? {
        let start = hex.index(hex.startIndex, offsetBy: offset)
        let end = hex.index(start, offsetBy: 2)
        return Int(hex[start..<end], radix: 16)
    }
}
