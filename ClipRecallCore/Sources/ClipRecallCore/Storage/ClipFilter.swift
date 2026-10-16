import Foundation

// MARK: - 过滤器模型（T3.2.1）

/// 组合查询过滤器：类型 / 来源 App / 时间，任意组合（nil = 不限）。
public struct ClipFilter: Sendable, Equatable {
    /// 按类型过滤（nil = 不限；空集合 = 不限）。
    public var types: Set<ClipType>?
    /// 按来源 App 过滤（bundleId；nil = 不限）。
    public var sourceAppBundleId: String?
    /// 按时间范围过滤（nil = 全部时间）。
    public var timeRange: ClipTimeRange?

    public init(
        types: Set<ClipType>? = nil,
        sourceAppBundleId: String? = nil,
        timeRange: ClipTimeRange? = nil
    ) {
        self.types = types
        self.sourceAppBundleId = sourceAppBundleId
        self.timeRange = timeRange
    }

    /// 是否有任何生效的过滤条件。
    public var isActive: Bool {
        (types?.isEmpty == false) || sourceAppBundleId != nil || timeRange != nil
    }
}

/// 时间过滤预设（"全部" = nil）。
public enum ClipTimeRange: Sendable, Equatable {
    /// 今天（自然日 0 点起）。
    case today
    /// 近 7 天（滚动窗口）。
    case last7Days
    /// 近 30 天（滚动窗口）。
    case last30Days

    /// 时间下界：capturedAt >= 此值即命中。
    public func cutoff(from now: Date = Date()) -> Date {
        switch self {
        case .today:
            return Calendar.current.startOfDay(for: now)
        case .last7Days:
            return now.addingTimeInterval(-7 * 86_400)
        case .last30Days:
            return now.addingTimeInterval(-30 * 86_400)
        }
    }
}
