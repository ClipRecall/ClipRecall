import Foundation

/// 敏感内容类别。
public enum SensitiveKind: String, Codable, Sendable {
    case cardNumber = "cardNumber"
    case apiKey = "apiKey"
}

/// 打码位置。
public enum MaskPosition: String, Codable, Sendable {
    case leading    // 前部打码
    case middle     // 中部打码
    case trailing   // 后部打码（默认）
}

/// 敏感内容检测结果。
public struct SensitiveContentInfo: Equatable, Sendable {
    public let kind: SensitiveKind
    public let maskedPreview: String
}

/// 敏感内容检测：识别银行卡号 / API 密钥形态，并按比例与位置生成脱敏预览。
/// 检测不改变原始内容——打码只作用于预览（召回粘贴仍是完整原内容）。
public enum SensitiveContentDetection {
    /// - Parameters:
    ///   - maskingRatio: 打码比例 0–1（0 = 不遮只提示；1 = 全遮）
    ///   - maskPosition: 打码位置（默认后部）
    public static func detect(
        in text: String,
        maskingRatio: Double = 0.5,
        maskPosition: MaskPosition = .trailing
    ) -> SensitiveContentInfo? {
        var masked = text
        var kind: SensitiveKind?

        // 卡号：13–19 位数字（允许空格 / 连字符分隔）
        let cardPattern = try! NSRegularExpression(pattern: "\\d[\\d \\-]{11,18}\\d")
        for match in cardPattern
            .matches(in: masked, range: NSRange(masked.startIndex..<masked.endIndex, in: masked))
            .reversed() {
            let substring = (masked as NSString).substring(with: match.range)
            guard (13...19).contains(substring.filter(\.isNumber).count) else { continue }
            masked = (masked as NSString).replacingCharacters(
                in: match.range, with: mask(substring, ratio: maskingRatio, position: maskPosition)
            )
            kind = kind ?? .cardNumber
        }

        // API 密钥类
        let keyPattern = try! NSRegularExpression(
            pattern: "(?i)\\b(sk-[a-z0-9_-]{8,}|(?:api[_-]?key|apikey|secret|token|access[_-]?key)\\s*[:=]\\s*[a-z0-9._-]{8,})"
        )
        for match in keyPattern
            .matches(in: masked, range: NSRange(masked.startIndex..<masked.endIndex, in: masked))
            .reversed() {
            let substring = (masked as NSString).substring(with: match.range)
            masked = (masked as NSString).replacingCharacters(
                in: match.range, with: mask(substring, ratio: maskingRatio, position: maskPosition)
            )
            kind = kind ?? .apiKey
        }

        guard let kind else { return nil }
        return SensitiveContentInfo(kind: kind, maskedPreview: masked)
    }

    /// 按比例与位置打码（比例钳制 0–1）。
    static func mask(_ string: String, ratio: Double, position: MaskPosition) -> String {
        let clamped = min(max(ratio, 0), 1)
        let count = string.count
        let maskedCount = Int((Double(count) * clamped).rounded(.down))
        guard maskedCount > 0 else { return string }
        let stars = String(repeating: "*", count: maskedCount)
        switch position {
        case .leading:
            return stars + String(string.dropFirst(maskedCount))
        case .trailing:
            return String(string.dropLast(maskedCount)) + stars
        case .middle:
            let keepEach = (count - maskedCount) / 2
            let head = string.prefix(keepEach)
            let tail = string.suffix(count - keepEach - maskedCount)
            return String(head) + stars + String(tail)
        }
    }
}
