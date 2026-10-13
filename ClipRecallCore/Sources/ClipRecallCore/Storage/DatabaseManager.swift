import Foundation
import GRDB

/// 数据库连接管理者：负责打开与持有 ClipRecall 的 SQLite 连接池。
/// 全局单例 `DatabaseManager.shared`；测试可通过自定义目录构造独立实例。
public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    private static let databaseFileName = "cliprecall.sqlite"

    private let directoryURL: URL
    private let lock = NSLock()
    private var pool: DatabasePool?

    /// - Parameter directoryURL: 数据库所在目录；默认系统 Application Support/ClipRecall。
    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directoryURL = base.appendingPathComponent("ClipRecall", isDirectory: true)
        }
    }

    /// 数据库文件完整路径
    public var databaseURL: URL {
        directoryURL.appendingPathComponent(Self.databaseFileName)
    }

    /// 打开连接池；幂等——已打开时直接返回已有连接。
    /// 目录不存在时自动创建（含嵌套目录）。
    public func open() throws -> DatabasePool {
        lock.lock()
        defer { lock.unlock() }
        if let pool { return pool }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let newPool = try DatabasePool(path: databaseURL.path)
        pool = newPool
        return newPool
    }
}
