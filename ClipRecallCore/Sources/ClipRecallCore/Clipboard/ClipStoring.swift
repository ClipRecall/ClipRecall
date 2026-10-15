import Foundation

/// 条目存储抽象：管道写入、界面读取。
/// 实现方：RecentClipsStore（内存，测试用）与 ClipRepository（数据库，正式用）。
public protocol ClipStoring: Sendable {
    /// 新条目保存后的通知（在写入线程执行）。
    var onAppend: (@Sendable (Clip) -> Void)? { get set }

    /// 保存条目；实现方负责分片合并与全局去重策略。
    func append(_ clip: Clip) throws

    /// 最近 N 条未删除条目（最新在前）。
    func recent(limit: Int) throws -> [Clip]
}
