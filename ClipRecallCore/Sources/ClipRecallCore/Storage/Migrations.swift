import Foundation
import GRDB

/// 数据库迁移注册（architecture 4.3 的表结构落地）。
public enum DatabaseMigrations {
    /// 注册全部迁移。编号只增不减，已发布的迁移内容不可修改。
    public static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_createClipsAndFormats") { db in
            try createClipsTable(db)
            try createFormatsTable(db)
        }
        migrator.registerMigration("v2_createSettings") { db in
            try createSettingsTable(db)
        }
        migrator.registerMigration("v3_createFTS") { db in
            try createFTSTable(db)
        }
        migrator.registerMigration("v4_addOCRText") { db in
            // OCR 识别文本（T3.3.2）：NULL = 尚未识别；空字符串 = 识别过但无文字/识别失败。
            // 断点续传由该列表达——重启后 NULL 的条目自动续处理。
            try db.alter(table: "clips") { t in
                t.add(column: "ocrText", .text)
            }
        }
    }

    /// 全文搜索索引（T3.1.1）：clipId 只做关联键不参与分词，text 为可搜索文本。
    private static func createFTSTable(_ db: Database) throws {
        try db.create(virtualTable: "fts", using: FTS5()) { t in
            t.column("clipId").notIndexed()
            t.column("text")
        }
    }

    private static func createSettingsTable(_ db: Database) throws {
        try db.create(table: "settings") { t in
            t.column("key", .text).notNull().primaryKey()
            t.column("value", .text).notNull()
        }
    }

    private static func createClipsTable(_ db: Database) throws {
        try db.create(table: "clips") { t in
            t.column("id", .text).notNull().primaryKey()
            t.column("capturedAt", .datetime).notNull().indexed()
            t.column("sourceAppBundleId", .text)
            t.column("sourceAppName", .text)
            t.column("primaryType", .text).notNull()
            t.column("textPreview", .text)
            t.column("pinned", .boolean).notNull().defaults(to: false)
            t.column("tags", .text).notNull().defaults(to: "[]")
            t.column("groupId", .text)
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }

    private static func createFormatsTable(_ db: Database) throws {
        try db.create(table: "formats") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("clipId", .text).notNull().indexed()
            t.column("type", .text).notNull()
            t.column("payloadKind", .text).notNull()
            t.column("payloadInline", .blob)
            t.column("payloadPath", .text)
            t.column("metadata", .text)
            t.column("version", .integer).notNull().defaults(to: 1)
        }
    }
}
