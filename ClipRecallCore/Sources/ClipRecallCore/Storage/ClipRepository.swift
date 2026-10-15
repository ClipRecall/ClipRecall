import Foundation
import GRDB

// MARK: - 记录层（数据库行映射）

struct ClipRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clips"

    var id: String
    var capturedAt: String
    var sourceAppBundleId: String?
    var sourceAppName: String?
    var primaryType: String
    var textPreview: String?
    var pinned: Bool
    var tags: String
    var groupId: String?
    var updatedAt: String
    var isDeleted: Bool
}

struct FormatRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "formats"

    var id: Int64?
    var clipId: String
    var type: String
    var payloadKind: String
    var payloadInline: Data?
    var payloadPath: String?
    var metadata: String?
    var version: Int
}

// MARK: - 仓储

/// 剪贴板条目仓储：数据库持久化（写入 / 查询 / 更新 / 软删除）。
/// save 时执行与内存存储一致的追加策略（分片合并 + 全局去重）。
public final class ClipRepository: @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let lock = NSLock()
    private var appendCallback: (@Sendable (Clip) -> Void)?

    public init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    /// 新条目保存后的通知（在写入线程执行）。
    public func setOnAppend(_ callback: @escaping @Sendable (Clip) -> Void) {
        lock.lock()
        appendCallback = callback
        lock.unlock()
    }

    /// 保存条目（含全部格式）；执行分片合并与全局去重（最近 200 条范围内）。
    public func save(_ clip: Clip) throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            // 分片合并：最新一条为前缀续写 → 删除旧条目
            if let latest = try recentClips(limit: 1, in: db).first,
               ClipAppendPolicy.isContinuation(of: latest, by: clip, window: 1.5) {
                try deleteClipRows(id: latest.id.uuidString, in: db)
            }
            // 全局去重：最近 200 条内身份相同 → 删除旧条目
            let recent = try recentClips(limit: 200, in: db)
            if let duplicate = recent.first(where: {
                ClipAppendPolicy.identity(of: $0) == ClipAppendPolicy.identity(of: clip)
            }) {
                try deleteClipRows(id: duplicate.id.uuidString, in: db)
            }
            try insertClip(clip, in: db)
        }
        notifyAppend(clip)
    }

    /// 最近 N 条未删除条目（最新在前）。
    public func fetchRecent(limit: Int) throws -> [Clip] {
        let pool = try databaseManager.open()
        return try pool.read { db in
            try recentClips(limit: limit, in: db)
        }
    }

    /// 更新条目（按 id，整体替换）。
    public func update(_ clip: Clip) throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            try deleteClipRows(id: clip.id.uuidString, in: db)
            try insertClip(clip, in: db)
        }
    }

    /// 软删除（tombstone）。
    public func delete(id: UUID) throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            try db.execute(
                sql: "UPDATE clips SET isDeleted = 1, updatedAt = ? WHERE id = ?",
                arguments: [Self.dateString(Date()), id.uuidString]
            )
        }
    }

    // MARK: - 内部：写入

    private func insertClip(_ clip: Clip, in db: Database) throws {
        try ClipRecord(
            id: clip.id.uuidString,
            capturedAt: Self.dateString(clip.capturedAt),
            sourceAppBundleId: clip.sourceApp?.bundleId,
            sourceAppName: clip.sourceApp?.name,
            primaryType: clip.primaryType.rawValue,
            textPreview: clip.textPreview,
            pinned: clip.pinned,
            tags: Self.encodeJSON(clip.tags),
            groupId: clip.groupId?.uuidString,
            updatedAt: Self.dateString(clip.updatedAt),
            isDeleted: clip.isDeleted
        ).insert(db)
        for format in clip.formats {
            try insertFormat(format, clipId: clip.id.uuidString, in: db)
        }
    }

    private func insertFormat(_ format: Format, clipId: String, in db: Database) throws {
        var record = FormatRecord(
            id: nil,
            clipId: clipId,
            type: format.type,
            payloadKind: "",
            payloadInline: nil,
            payloadPath: nil,
            metadata: Self.encodeJSON(format.metadata),
            version: format.version
        )
        switch format.payload {
        case .inline(let data):
            record.payloadKind = "inline"
            record.payloadInline = data
        case .file(let path):
            record.payloadKind = "file"
            record.payloadPath = path
        }
        try record.insert(db)
    }

    private func deleteClipRows(id: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM formats WHERE clipId = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM clips WHERE id = ?", arguments: [id])
    }

    // MARK: - 内部：查询

    private func recentClips(limit: Int, in db: Database) throws -> [Clip] {
        let records = try ClipRecord
            .filter(Column("isDeleted") == false)
            .order(Column("capturedAt").desc)
            .limit(limit)
            .fetchAll(db)
        guard !records.isEmpty else { return [] }
        let ids = records.map(\.id)
        let formatRecords = try FormatRecord
            .filter(ids.contains(Column("clipId")))
            .fetchAll(db)
        let formatsByClip = Dictionary(grouping: formatRecords, by: \.clipId)
        return records.compactMap { record in
            Self.makeClip(record: record, formats: formatsByClip[record.id] ?? [])
        }
    }

    // MARK: - 内部：映射

    private static func makeClip(record: ClipRecord, formats: [FormatRecord]) -> Clip? {
        guard let id = UUID(uuidString: record.id),
              let primaryType = ClipType(rawValue: record.primaryType),
              let capturedAt = date(from: record.capturedAt),
              let updatedAt = date(from: record.updatedAt)
        else { return nil }
        let sourceApp: SourceApp?
        if let bundleId = record.sourceAppBundleId, let name = record.sourceAppName {
            sourceApp = SourceApp(bundleId: bundleId, name: name)
        } else {
            sourceApp = nil
        }
        return Clip(
            id: id,
            capturedAt: capturedAt,
            sourceApp: sourceApp,
            primaryType: primaryType,
            formats: formats.compactMap { makeFormat(record: $0) },
            textPreview: record.textPreview,
            pinned: record.pinned,
            tags: decodeJSON(record.tags) ?? [],
            groupId: record.groupId.flatMap(UUID.init(uuidString:)),
            updatedAt: updatedAt,
            isDeleted: record.isDeleted
        )
    }

    private static func makeFormat(record: FormatRecord) -> Format? {
        let payload: Payload
        switch record.payloadKind {
        case "inline":
            guard let data = record.payloadInline else { return nil }
            payload = .inline(data)
        case "file":
            guard let path = record.payloadPath else { return nil }
            payload = .file(path: path)
        default:
            return nil
        }
        return Format(
            type: record.type,
            payload: payload,
            metadata: decodeJSON(record.metadata ?? "") ?? FormatMetadata(),
            version: record.version
        )
    }

    // MARK: - 序列化辅助

    /// 定宽 UTC ISO8601（含毫秒）：字典序即时间序。
    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    static func dateString(_ date: Date) -> String {
        makeISOFormatter().string(from: date)
    }

    static func date(from string: String) -> Date? {
        makeISOFormatter().date(from: string)
    }

    static func encodeJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else { return "null" }
        return string
    }

    static func decodeJSON<T: Decodable>(_ string: String) -> T? {
        let decoder = JSONDecoder()
        guard let data = string.data(using: .utf8) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func notifyAppend(_ clip: Clip) {
        lock.lock()
        let callback = appendCallback
        lock.unlock()
        callback?(clip)
    }
}
