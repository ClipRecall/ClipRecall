import Foundation

/// 历史保留策略：条数 / 天数上限（0 = 不限）。
/// 默认值见架构文档（2000 条 / 30 天）；设置页（T2.6.2）完成后由 UI 读写。
public struct RetentionPolicy: Equatable, Sendable {
    /// 最大条数（0 = 不限）
    public var maxCount: Int
    /// 最大天数（0 = 不限）
    public var maxDays: Int

    public init(maxCount: Int = 2000, maxDays: Int = 30) {
        self.maxCount = maxCount
        self.maxDays = maxDays
    }
}
