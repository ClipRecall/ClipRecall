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
public final class ClipRepository: ClipStoring, @unchecked Sendable {
    private let databaseManager: DatabaseManager
    private let blobManager: BlobFileManager
    private let lock = NSLock()
    private var appendCallback: (@Sendable (Clip) -> Void)?
    private var retentionPolicy: RetentionPolicy

    public init(
        databaseManager: DatabaseManager = .shared,
        blobManager: BlobFileManager = .shared,
        retentionPolicy: RetentionPolicy = RetentionPolicy()
    ) {
        self.databaseManager = databaseManager
        self.blobManager = blobManager
        self.retentionPolicy = retentionPolicy
    }

    /// 更新保留策略（设置页 T2.6.2 接入后由 UI 调用）。
    public func setRetentionPolicy(_ policy: RetentionPolicy) {
        lock.lock()
        retentionPolicy = policy
        lock.unlock()
    }

    /// 新条目保存后的通知（在写入线程执行）。
    public var onAppend: (@Sendable (Clip) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return appendCallback
        }
        set {
            lock.lock()
            appendCallback = newValue
            lock.unlock()
        }
    }

    public func append(_ clip: Clip) throws {
        try save(clip)
    }

    public func recent(limit: Int) throws -> [Clip] {
        try fetchRecent(limit: limit)
    }

    /// 调试用批量插入：绕过合并/去重/清理策略，直接落库（性能测试用；正式版发布前移除，见 T7.5）。
    public func bulkInsertForTesting(_ clips: [Clip]) throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            for clip in clips {
                try insertClip(clip, in: db)
            }
        }
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
        try cleanupIfNeeded()
        notifyAppend(clip)
    }

    /// 最近 N 条未删除条目（最新在前）。
    public func fetchRecent(limit: Int) throws -> [Clip] {
        let pool = try databaseManager.open()
        return try pool.read { db in
            try recentClips(limit: limit, in: db)
        }
    }

    /// 全文搜索（T3.1.2）：FTS5 短语匹配；中文查询附加 LIKE 子串并集兜底
    /// （unicode61 分词器对夹标点等场景分词不佳，兜底保证不丢召回）；纯符号查询只走 LIKE。
    /// 只搜索打码后的预览文本——敏感内容完整值不可搜（隐私设计，与 T3.1.1 一致）。
    public func search(_ query: String, limit: Int = 100) throws -> [Clip] {
        // 关键词接口语义：空关键词返回空（只按过滤器查请走 fetchClips）
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return try fetchClips(query: query, filter: ClipFilter(), limit: limit)
    }

    /// 组合查询（T3.2.1）：关键词 + 类型 / 来源 / 时间过滤任意组合，一次查询完成。
    /// 关键词为空时只按过滤器查（搜索框空 + 过滤激活的场景）；空过滤器等价最近列表。
    public func fetchClips(
        query: String, filter: ClipFilter = ClipFilter(), limit: Int = 100
    ) throws -> [Clip] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let pool = try databaseManager.open()
        return try pool.read { db in
            // 关键词 → id 集合（复用 FTS 短语 + 中文/符号 LIKE 兜底）
            var keywordIds: Set<String>?
            if !trimmed.isEmpty {
                var ids: [String] = []
                if trimmed.containsTokenCharacter {
                    ids = try Self.ftsMatch(trimmed, in: db)
                }
                if trimmed.containsCJK || !trimmed.containsTokenCharacter {
                    ids = Array(Set(ids + (try Self.likeMatch(trimmed, in: db))))
                }
                keywordIds = Set(ids)
            }
            var request = ClipRecord.filter(Column("isDeleted") == false)
            if let keywordIds {
                request = request.filter(keywordIds.contains(Column("id")))
            }
            if let types = filter.types, !types.isEmpty {
                request = request.filter(types.map(\.rawValue).contains(Column("primaryType")))
            }
            if let bundleId = filter.sourceAppBundleId {
                request = request.filter(Column("sourceAppBundleId") == bundleId)
            }
            if let cutoff = filter.timeRange?.cutoff() {
                request = request.filter(Column("capturedAt") >= Self.dateString(cutoff))
            }
            let records = try request
                .order(Column("capturedAt").desc)
                .limit(limit)
                .fetchAll(db)
            let finalIds = records.map(\.id)
            let formatRecords = try FormatRecord
                .filter(finalIds.contains(Column("clipId")))
                .fetchAll(db)
            let formatsByClip = Dictionary(grouping: formatRecords, by: \.clipId)
            return records.compactMap { record in
                Self.makeClip(record: record, formats: formatsByClip[record.id] ?? [])
            }
        }
    }

    /// 历史中出现过的来源 App（T3.2.2 过滤栏数据源）：去重、排除软删除、按名称排序。
    public func fetchSourceApps() throws -> [(bundleId: String, name: String)] {
        let pool = try databaseManager.open()
        return try pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT sourceAppBundleId, sourceAppName FROM clips
                    WHERE isDeleted = 0 AND sourceAppBundleId IS NOT NULL
                    GROUP BY sourceAppBundleId
                    ORDER BY sourceAppName COLLATE NOCASE
                    """
            )
            return rows.compactMap { row in
                guard let bundleId = row["sourceAppBundleId"] as String?,
                      let name = row["sourceAppName"] as String?
                else { return nil }
                return (bundleId, name)
            }
        }
    }

    /// 全量重建搜索索引（T3.1.3）：清空 fts 后从 clips 表重新灌入未删除条目的预览文本。
    /// 覆盖场景：升级到 v3 后旧历史补索引、索引漂移修复。返回重建的行数。
    @discardableResult
    public func rebuildSearchIndex() throws -> Int {
        let pool = try databaseManager.open()
        return try pool.write { db in
            try Self.rebuildFTSTable(in: db)
        }
    }

    /// 自愈检查：索引行数与活条目数不一致时自动重建（App 启动时调用一次）。
    /// 正常写入全走事务不会漂移，不一致只可能来自升级空表、bug 或外部改动。
    /// 返回是否执行了重建。
    @discardableResult
    public func rebuildSearchIndexIfNeeded() throws -> Bool {
        let pool = try databaseManager.open()
        return try pool.write { db in
            let liveCount = try ClipRecord.filter(Column("isDeleted") == false).fetchCount(db)
            let indexCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM fts") ?? 0
            guard liveCount != indexCount else { return false }
            _ = try Self.rebuildFTSTable(in: db)
            return true
        }
    }

    /// 清空 fts 并从 clips 表重新灌入未删除条目的预览文本；返回重建行数。
    private static func rebuildFTSTable(in db: Database) throws -> Int {
        try db.execute(sql: "DELETE FROM fts")
        try db.execute(sql: """
            INSERT INTO fts (clipId, text)
            SELECT id, COALESCE(textPreview, '') FROM clips WHERE isDeleted = 0
            """)
        return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM fts") ?? 0
    }

    /// FTS 短语匹配：整体包成短语并转义内部引号，避免用户输入触发 FTS 查询语法。
    private static func ftsMatch(_ query: String, in db: Database) throws -> [String] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        return try String.fetchAll(
            db, sql: "SELECT clipId FROM fts WHERE fts MATCH ?", arguments: ["\"\(escaped)\""]
        )
    }

    /// LIKE 兜底（中文）：转义通配符后做子串匹配，仅在 textPreview 上扫描。
    private static func likeMatch(_ query: String, in db: Database) throws -> [String] {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return try String.fetchAll(
            db,
            sql: "SELECT id FROM clips WHERE textPreview LIKE ? ESCAPE '\\' AND isDeleted = 0",
            arguments: ["%\(escaped)%"]
        )
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
            // 软删除条目同样退出搜索索引
            try db.execute(sql: "DELETE FROM fts WHERE clipId = ?", arguments: [id.uuidString])
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
        // 全文搜索索引（T3.1.1）：只索引打码后的预览文本，敏感内容完整值不可被搜索
        try db.execute(
            sql: "INSERT INTO fts (clipId, text) VALUES (?, ?)",
            arguments: [clip.id.uuidString, clip.textPreview ?? ""]
        )
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
        // 同步清理搜索索引（覆盖去重替换 / 合并替换 / 更新 / 保留清理 / 清空全部）
        try db.execute(sql: "DELETE FROM fts WHERE clipId = ?", arguments: [id])
    }

    /// 主动执行一次保留策略（App 启动时调用；save 内部也会自动执行）。
    public func enforceRetentionPolicy() throws {
        try cleanupIfNeeded()
    }

    /// 清空全部历史（硬删除，含落盘文件）；返回删除的条数。
    public func clearAll() throws -> Int {
        let pool = try databaseManager.open()
        var deletedPaths: [String] = []
        let count: Int = try pool.write { db in
            let rows = try ClipRecord.fetchAll(db)
            deletedPaths += try Self.collectBlobPaths(clipIds: rows.map(\.id), in: db)
            for row in rows {
                try deleteClipRows(id: row.id, in: db)
            }
            return rows.count
        }
        for path in deletedPaths {
            try? blobManager.delete(relativePath: path)
        }
        return count
    }

    /// 保存后自动执行保留策略（Pin 豁免；落盘文件一并删除，防孤儿文件）。
    private func cleanupIfNeeded() throws {
        lock.lock()
        let policy = retentionPolicy
        lock.unlock()
        guard policy.maxCount > 0 || policy.maxDays > 0 else { return }

        let pool = try databaseManager.open()
        var deletedPaths: [String] = []
        try pool.write { db in
            // 天数上限
            if policy.maxDays > 0 {
                let cutoff = Self.dateString(Date().addingTimeInterval(-Double(policy.maxDays) * 86_400))
                let rows = try ClipRecord
                    .filter(Column("isDeleted") == false && Column("pinned") == false && Column("capturedAt") < cutoff)
                    .fetchAll(db)
                deletedPaths += try Self.collectBlobPaths(clipIds: rows.map(\.id), in: db)
                for row in rows {
                    try deleteClipRows(id: row.id, in: db)
                }
            }
            // 条数上限（最旧的未固定条目先清）
            if policy.maxCount > 0 {
                let count = try ClipRecord.filter(Column("isDeleted") == false).fetchCount(db)
                if count > policy.maxCount {
                    let excess = count - policy.maxCount
                    let rows = try ClipRecord
                        .filter(Column("isDeleted") == false && Column("pinned") == false)
                        .order(Column("capturedAt").asc)
                        .limit(excess)
                        .fetchAll(db)
                    deletedPaths += try Self.collectBlobPaths(clipIds: rows.map(\.id), in: db)
                    for row in rows {
                        try deleteClipRows(id: row.id, in: db)
                    }
                }
            }
        }
        for path in deletedPaths {
            try? blobManager.delete(relativePath: path)
        }
    }

    private static func collectBlobPaths(clipIds: [String], in db: Database) throws -> [String] {
        guard !clipIds.isEmpty else { return [] }
        let records = try FormatRecord
            .filter(clipIds.contains(Column("clipId")) && Column("payloadKind") == "file")
            .fetchAll(db)
        return records.compactMap(\.payloadPath)
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

private extension String {
    /// CJK 字符区段（扩展 A / 统一表意文字 / 兼容表意文字）。
    static let cjkRanges: [ClosedRange<UInt32>] = [
        0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
    ]

    /// 是否包含 CJK 字符（搜索含中文时启用 LIKE 兜底）。
    var containsCJK: Bool {
        unicodeScalars.contains { scalar in
            Self.cjkRanges.contains { $0.contains(scalar.value) }
        }
    }

    /// 是否含可分词字符（字母 / 十进制数字 / CJK）。纯符号查询无法走 FTS（空短语），转 LIKE。
    /// 注意：不能用 CharacterSet.alphanumerics——它会误判 ①② 等带圈数字为可分词字符。
    var containsTokenCharacter: Bool {
        unicodeScalars.contains { scalar in
            let properties = scalar.properties
            return properties.isAlphabetic
                || properties.generalCategory == .decimalNumber
                || containsCJK
        }
    }
}
