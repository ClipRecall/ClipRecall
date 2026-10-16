import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.1.3：搜索索引全量重建与自愈检查。
final class ClipIndexRebuildTests: XCTestCase {
    private var tempDirectory: URL!
    private var databaseManager: DatabaseManager!
    private var repository: ClipRepository!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        let manager = DatabaseManager(directoryURL: tempDirectory)
        databaseManager = manager
        repository = ClipRepository(databaseManager: manager)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeClip(_ text: String) -> Clip {
        Clip(
            capturedAt: Date(),
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    /// 模拟索引被清空（升级到 v3 后的空表状态）。
    private func wipeIndex() throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            try db.execute(sql: "DELETE FROM fts")
        }
    }

    func testRebuildPopulatesEmptyIndex() throws {
        try repository.save(makeClip("alpha one"))
        try repository.save(makeClip("beta two"))
        try wipeIndex()
        XCTAssertEqual(try repository.rebuildSearchIndex(), 2)
        XCTAssertEqual(try repository.search("alpha").count, 1)
        XCTAssertEqual(try repository.search("beta").count, 1)
    }

    func testRebuildExcludesSoftDeleted() throws {
        let clip = makeClip("alpha one")
        try repository.save(clip)
        try repository.save(makeClip("beta two"))
        try repository.delete(id: clip.id)
        XCTAssertEqual(try repository.rebuildSearchIndex(), 1)
        XCTAssertTrue(try repository.search("alpha").isEmpty)
        XCTAssertEqual(try repository.search("beta").count, 1)
    }

    func testRebuildIfNeededDetectsAndFixes() throws {
        try repository.save(makeClip("alpha one"))
        try wipeIndex()
        // 第一次：检测到不一致 → 重建
        XCTAssertTrue(try repository.rebuildSearchIndexIfNeeded())
        XCTAssertEqual(try repository.search("alpha").count, 1)
        // 第二次：已同步 → no-op
        XCTAssertFalse(try repository.rebuildSearchIndexIfNeeded())
    }

    func testRebuildIfNeededNoOpWhenInSync() throws {
        try repository.save(makeClip("alpha one"))
        try repository.save(makeClip("beta two"))
        XCTAssertFalse(try repository.rebuildSearchIndexIfNeeded())
        XCTAssertEqual(try repository.search("alpha").count, 1)
        XCTAssertEqual(try repository.search("beta").count, 1)
    }

    func testRebuildRemovesGhostRows() throws {
        // 索引多于条目（幽灵行）：自愈重建后清除
        try repository.save(makeClip("alpha one"))
        let pool = try databaseManager.open()
        try pool.write { db in
            try db.execute(sql: "INSERT INTO fts (clipId, text) VALUES ('ghost', 'phantom')")
        }
        XCTAssertTrue(try repository.rebuildSearchIndexIfNeeded())
        XCTAssertTrue(try repository.search("phantom").isEmpty)
        XCTAssertEqual(try repository.search("alpha").count, 1)
    }
}
