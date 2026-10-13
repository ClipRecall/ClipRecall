import XCTest
import GRDB
@testable import ClipRecallCore

final class MigrationsTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testOpenCreatesBothTables() throws {
        let pool = try DatabaseManager(directoryURL: tempDirectory).open()
        try pool.read { db in
            XCTAssertTrue(try db.tableExists("clips"))
            XCTAssertTrue(try db.tableExists("formats"))
        }
    }

    func testClipsTableHasExpectedColumns() throws {
        let pool = try DatabaseManager(directoryURL: tempDirectory).open()
        let columns = try pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(clips)").map { $0["name"] as String }
        }
        for expected in ["id", "capturedAt", "primaryType", "pinned", "tags", "updatedAt", "isDeleted"] {
            XCTAssertTrue(columns.contains(expected), "clips 表缺少列：\(expected)")
        }
    }

    func testMigrationIsIdempotentAcrossManagers() throws {
        // 两个独立管理器指向同一路径：第二个打开时迁移应静默跳过、不报错
        _ = try DatabaseManager(directoryURL: tempDirectory).open()
        let second = try DatabaseManager(directoryURL: tempDirectory).open()
        try second.read { db in
            XCTAssertTrue(try db.tableExists("clips"))
        }
    }
}
