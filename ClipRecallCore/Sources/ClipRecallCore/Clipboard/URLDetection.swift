import Foundation

/// URL 识别结果。
public struct URLInfo: Equatable, Sendable {
    /// 规范化后的完整 URL
    public let urlString: String
    /// 域名（如 github.com；www. 前缀已去除）
    public let domain: String
}

/// URL 检测：判断整段文本是否"就是一条网址"（派生类型 url 的识别依据）。
public enum URLDetection {
    /// 检测整段文本是否为网址；否则返回 nil。
    /// 规则：
    /// - 整段文本必须无空白字符（多行 / 句子不识别）；
    /// - 支持 http(s):// 前缀、www. 前缀、裸域名；
    /// - 裸域名要求最后一段为纯字母且 ≥2 位（拦截 "1.2" 类数字）。
    public static func detect(in text: String) -> URLInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace })
        else { return nil }

        let candidate: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            candidate = trimmed
        } else {
            candidate = "https://" + trimmed
        }

        guard let url = URL(string: candidate),
              let host = url.host,
              host.contains(".")
        else { return nil }

        // 裸域名形态：额外校验最后一段（TLD 位置）为纯字母
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            guard hasAlphabeticTLD(host) else { return nil }
        }

        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return URLInfo(urlString: trimmed, domain: domain)
    }

    /// 最后一段（TLD 位置）为纯字母且 ≥2 位。
    private static func hasAlphabeticTLD(_ host: String) -> Bool {
        guard let tld = host.split(separator: ".").last else { return false }
        return tld.count >= 2 && tld.allSatisfy { $0.isLetter }
    }
}
