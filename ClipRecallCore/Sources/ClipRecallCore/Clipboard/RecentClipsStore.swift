import Foundation

/// 内存历史缓存：调试阶段保存最近 N 个采集结果（T1.6 入库后由数据库替代）。
/// 最新在前；超过上限自动淘汰最旧。
public final class RecentClipsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Clip] = []
    private let limit: Int
    private let mergeWindow: TimeInterval

    /// 新条目追加时的回调（在追加线程执行）。
    public var onAppend: (@Sendable (Clip) -> Void)?

    /// - Parameters:
    ///   - limit: 条目上限
    ///   - mergeWindow: 分片合并时间窗口（秒）；窗口内"前缀续写"视为同一份内容的追加
    public init(limit: Int = 50, mergeWindow: TimeInterval = 1.5) {
        self.limit = limit
        self.mergeWindow = mergeWindow
    }

    /// 当前条目（最新在前）。
    public var clips: [Clip] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    /// 追加条目。存储层负责两个策略（T1.5，T1.6 数据库入库时沿用）：
    /// 1. 分片合并：窗口内新内容以最新一条为前缀且更长 → 视为续写，替换旧条目；
    /// 2. 全局去重：与列表中任一条内容相同（身份一致）→ 移除旧条目、新条目置顶。
    public func append(_ clip: Clip) {
        lock.lock()
        if let first = items.first,
           let delta = Optional(clip.capturedAt.timeIntervalSince(first.capturedAt)),
           delta >= 0, delta <= mergeWindow,
           isContinuation(of: first, by: clip) {
            items.removeFirst()
            items.insert(clip, at: 0)
            lock.unlock()
            onAppend?(clip)
            return
        }
        let identity = FormatFingerprint.contentIdentity(from: clip.formats)
        items.removeAll { FormatFingerprint.contentIdentity(from: $0.formats) == identity }
        items.insert(clip, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        lock.unlock()
        onAppend?(clip)
    }

    /// 续写判据：两者都有纯文本，且新文本以旧文本为前缀且更长。
    private func isContinuation(of previous: Clip, by new: Clip) -> Bool {
        guard let previousText = plainText(of: previous),
              let newText = plainText(of: new)
        else { return false }
        return newText.hasPrefix(previousText) && newText.count > previousText.count
    }

    private func plainText(of clip: Clip) -> String? {
        guard let plain = clip.formats.first(where: { $0.type == FormatUTI.plainText }),
              case .inline(let data) = plain.payload,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}
