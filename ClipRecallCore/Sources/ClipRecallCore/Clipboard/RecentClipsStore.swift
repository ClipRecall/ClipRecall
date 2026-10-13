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

    public func append(_ clip: Clip) {
        lock.lock()
        items.insert(clip, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        lock.unlock()
        onAppend?(clip)
    }
}
