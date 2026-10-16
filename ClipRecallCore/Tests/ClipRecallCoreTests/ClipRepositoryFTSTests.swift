import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.1.1：FTS5 搜索索引与仓储写入/删除的同步。
final class ClipRepositoryFTSTests: XCTestCase {
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

    private func makeClip(_ text: String, capturedAt: Date = Date()) -> Clip {
        Clip(
            capturedAt: capturedAt,
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    /// 用 FTS 匹配查询索引中的 clipId（测试读取入口）。
    private func searchClipIDs(matching pattern: String) throws -> [String] {
        let pool = try databaseManager.open()
        return try pool.read { db in
            try String.fetchAll(
                db, sql: "SELECT clipId FROM fts WHERE fts MATCH ?", arguments: [pattern]
            )
        }
    }

    func testSaveWritesSearchIndex() throws {
        try repository.save(makeClip("hello alpha"))
        try repository.save(makeClip("hello beta"))
        // 各自关键词可命中，且互不串扰
        XCTAssertEqual(try searchClipIDs(matching: "alpha").count, 1)
        XCTAssertEqual(try searchClipIDs(matching: "beta").count, 1)
        // 大小写不敏感（unicode61 默认行为）
        XCTAssertEqual(try searchClipIDs(matching: "HELLO").count, 2)
    }

    func testTombstoneRemovesFromSearchIndex() throws {
        let clip = makeClip("unique zebra")
        try repository.save(clip)
        try repository.delete(id: clip.id)
        XCTAssertTrue(try searchClipIDs(matching: "zebra").isEmpty)
    }

    func testClearAllEmptiesSearchIndex() throws {
        try repository.save(makeClip("first word"))
        try repository.save(makeClip("second word"))
        _ = try repository.clearAll()
        XCTAssertTrue(try searchClipIDs(matching: "word").isEmpty)
    }

    func testUpdateRefreshesSearchIndex() throws {
        var clip = makeClip("old text gamma")
        try repository.save(clip)
        clip.textPreview = "new text delta"
        clip.formats = [Format(type: FormatUTI.plainText, payload: .inline(Data("new text delta".utf8)))]
        try repository.update(clip)
        XCTAssertTrue(try searchClipIDs(matching: "gamma").isEmpty)
        let hits = try searchClipIDs(matching: "delta")
        XCTAssertEqual(hits, [clip.id.uuidString])
    }

    func testDedupReplacementKeepsSingleIndexRow() throws {
        // 同一内容保存两次 → 去重替换旧条目，索引中也只保留新 clipId 一行
        try repository.save(makeClip("dedup epsilon"))
        Thread.sleep(forTimeInterval: 0.01)
        let second = makeClip("dedup epsilon")
        try repository.save(second)
        let hits = try searchClipIDs(matching: "epsilon")
        XCTAssertEqual(hits, [second.id.uuidString])
    }

    func testRetentionCleanupRemovesFromSearchIndex() throws {
        try repository.setRetentionPolicy(RetentionPolicy(maxCount: 1, maxDays: 0))
        try repository.save(makeClip("old zeta"))
        Thread.sleep(forTimeInterval: 0.01)
        try repository.save(makeClip("new eta"))
        XCTAssertTrue(try searchClipIDs(matching: "zeta").isEmpty)
        XCTAssertEqual(try searchClipIDs(matching: "eta").count, 1)
    }
}
