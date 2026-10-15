import Foundation

/// 条目追加策略：分片合并与全局去重的共享判定（内存缓存与数据库仓储共用）。
public enum ClipAppendPolicy {
    /// 续写判据：两者都有纯文本，新文本以旧文本为前缀且更长，且在时间窗口内。
    public static func isContinuation(of previous: Clip, by new: Clip, window: TimeInterval) -> Bool {
        let delta = new.capturedAt.timeIntervalSince(previous.capturedAt)
        guard delta >= 0, delta <= window else { return false }
        guard let previousText = plainText(of: previous),
              let newText = plainText(of: new)
        else { return false }
        return newText.hasPrefix(previousText) && newText.count > previousText.count
    }

    /// 内容身份（与 FormatFingerprint.contentIdentity 相同语义）。
    public static func identity(of clip: Clip) -> String {
        FormatFingerprint.contentIdentity(from: clip.formats)
    }

    /// 提取条目的纯文本内容（仅内联载荷）。
    public static func plainText(of clip: Clip) -> String? {
        guard let plain = clip.formats.first(where: { $0.type == FormatUTI.plainText }),
              case .inline(let data) = plain.payload,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}
