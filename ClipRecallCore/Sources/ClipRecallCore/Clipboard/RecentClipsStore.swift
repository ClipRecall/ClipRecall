import Foundation

/// 内存历史缓存：调试阶段保存最近 N 个采集结果（T1.6 入库后由数据库替代）。
/// 最新在前；超过上限自动淘汰最旧。
public final class RecentClipsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Clip] = []
    private let limit: Int

    /// 新条目追加时的回调（在追加线程执行）。
    public var onAppend: (@Sendable (Clip) -> Void)?

    public init(limit: Int = 50) {
        self.limit = limit
    }

    /// 当前条目（最新在前）。
    public var clips: [Clip] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    /// 追加条目；与列表中任一条内容相同（身份一致）时，移除旧条目、新条目置顶（时间更新）。
    /// 全局去重（T1.5.1）由存储层负责——T1.6 数据库入库时沿用同一策略。
    public func append(_ clip: Clip) {
        lock.lock()
        let identity = FormatFingerprint.contentIdentity(from: clip.formats)
        items.removeAll { FormatFingerprint.contentIdentity(from: $0.formats) == identity }
        items.insert(clip, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        lock.unlock()
        onAppend?(clip)
    }
}
