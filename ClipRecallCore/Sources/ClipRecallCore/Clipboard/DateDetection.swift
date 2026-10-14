import Foundation

/// 日期检测：整段文本是常见日期格式时识别。
public enum DateDetection {
    /// 检测整段文本是否为常见日期格式；否则返回 nil。
    public static func detect(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in patterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return trimmed
            }
        }
        return nil
    }

    /// 已知取舍：只做形态匹配，不校验月份/日期的合法范围（如 2024-13-45 也会识别）。
    private static let patterns = [
        "^\\d{4}-\\d{1,2}-\\d{1,2}$",      // 2024-01-15
        "^\\d{4}/\\d{1,2}/\\d{1,2}$",      // 2024/1/15
        "^\\d{1,2}/\\d{1,2}/\\d{4}$",      // 1/15/2024
        "^\\d{4}年\\d{1,2}月\\d{1,2}日$",   // 2024年1月15日
    ]
}
