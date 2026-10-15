import Foundation

/// 邮箱检测：整段文本是邮箱地址时识别。
public enum EmailDetection {
    /// 检测整段文本是否为邮箱；否则返回 nil。
    public static func detect(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return trimmed
    }

    /// 简单邮箱模式：local@domain.tld（TLD 纯字母 ≥2 位）
    private static let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
}
