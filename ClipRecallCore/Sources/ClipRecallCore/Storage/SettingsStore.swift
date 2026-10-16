import Foundation
import GRDB

/// 应用设置存储：settings 键值表读写（T2.6.1）。
/// 各类设置的语义与默认值由 App 层包装（如 RetentionPolicy / HotkeySettings）。
public final class SettingsStore: @unchecked Sendable {
    private let databaseManager: DatabaseManager

    public init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    /// 读取键值；不存在返回 nil。
    public func string(forKey key: String) -> String? {
        guard let pool = try? databaseManager.open() else { return nil }
        return try? pool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
        }
    }

    /// 写入键值（存在则覆盖）。
    public func set(_ value: String, forKey key: String) {
        guard let pool = try? databaseManager.open() else { return }
        try? pool.write { db in
            try db.execute(
                sql: "INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                arguments: [key, value]
            )
        }
    }

    /// 删除键。
    public func remove(key: String) {
        guard let pool = try? databaseManager.open() else { return }
        try? pool.write { db in
            try db.execute(sql: "DELETE FROM settings WHERE key = ?", arguments: [key])
        }
    }
}
