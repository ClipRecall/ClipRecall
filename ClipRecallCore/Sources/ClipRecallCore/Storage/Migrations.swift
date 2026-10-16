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
