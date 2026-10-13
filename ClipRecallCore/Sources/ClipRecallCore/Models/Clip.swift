import Foundation

/// 剪贴板条目：一条历史记录的完整档案（详见 architecture 4.1）。
public struct Clip: Codable, Hashable, Identifiable, Sendable {
    /// 客户端生成的唯一标识（同步幂等依赖它）
    public let id: UUID
    /// 捕获时间
    public var capturedAt: Date
    /// 来源应用；未知时为 nil
    public var sourceApp: SourceApp?
    /// 主类型（url / code / color 为派生类型）
    public var primaryType: ClipType
    /// 格式包：同一内容的多表示
    public var formats: [Format]
    /// 列表展示与搜索索引用的文本预览
    public var textPreview: String?
    /// 是否固定（不受保留策略清理）
    public var pinned: Bool
    /// 手动标签
    public var tags: [String]
    /// 分组（预留，当前版本不使用）
    public var groupId: UUID?
    /// 最后修改时间（LWW 冲突解决字段）
    public var updatedAt: Date
    /// 软删除标记（tombstone，同步用）
    public var isDeleted: Bool

    public init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        sourceApp: SourceApp? = nil,
        primaryType: ClipType,
        formats: [Format],
        textPreview: String? = nil,
        pinned: Bool = false,
        tags: [String] = [],
        groupId: UUID? = nil,
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.sourceApp = sourceApp
        self.primaryType = primaryType
        self.formats = formats
        self.textPreview = textPreview
        self.pinned = pinned
        self.tags = tags
        self.groupId = groupId
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
