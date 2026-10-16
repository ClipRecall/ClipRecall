import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.3.3：OCR 文本入搜索索引（setOCRText 同步 fts、重建保留 OCR、合并文本）。
final class OCRSearchTests: XCTestCase {
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

    private func makeImageClip() -> Clip {
        Clip(
            capturedAt: Date(),
            primaryType: .image,
            formats: [Format(type: FormatUTI.png, payload: .inline(Data([0x01])))]
        )
    }

    private func makeTextClip(_ text: String) -> Clip {
        Clip(
            capturedAt: Date(),
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    /// 模拟索引被清空（重建场景）。
    private func wipeIndex() throws {
        let pool = try databaseManager.open()
        try pool.write { db in
            try db.execute(sql: "DELETE FROM fts")
        }
    }

    func testOCRTextBecomesSearchableChinese() throws {
        let clip = makeImageClip()
        try repository.save(clip)
        // 纯图片条目（无预览）OCR 前不可搜
        XCTAssertTrue(try repository.search("会议纪要").isEmpty)
        try repository.setOCRText(clipId: clip.id, "会议纪要 2026")
        let hits = try repository.search("会议纪要")
        XCTAssertEqual(hits.map(\.id), [clip.id])
    }

    func testOCRTextBecomesSearchableEnglish() throws {
        let clip = makeImageClip()
        try repository.save(clip)
        try repository.setOCRText(clipId: clip.id, "quarterly report draft")
        XCTAssertEqual(try repository.search("quarterly").count, 1)
        // 部分词（子串兜底）也能命中
        XCTAssertEqual(try repository.search("quarter").count, 1)
    }

    func testRebuildPreservesOCRText() throws {
        let clip = makeImageClip()
        try repository.save(clip)
        try repository.setOCRText(clipId: clip.id, "重建后不丢失的截图文字")
        try wipeIndex()
        _ = try repository.rebuildSearchIndex()
        XCTAssertEqual(try repository.search("截图文字").count, 1)
    }

    func testEmptyOCRTextNoFalseHits() throws {
        let clip = makeImageClip()
        try repository.save(clip)
        try repository.setOCRText(clipId: clip.id, "")
        // 不误命中、不崩溃
        XCTAssertTrue(try repository.search("任何词").isEmpty)
        XCTAssertTrue(try repository.search("").isEmpty)
    }

    func testPreviewAndOCRTextBothSearchable() throws {
        let clip = makeTextClip("普通文本条目")
        try repository.save(clip)
        try repository.setOCRText(clipId: clip.id, "图片里的特殊内容")
        // 预览与 OCR 文本各自可搜（合并入同一索引行）
        XCTAssertEqual(try repository.search("普通文本").count, 1)
        XCTAssertEqual(try repository.search("特殊内容").count, 1)
        // 行数不变式保持：一条目一行
        let pool = try databaseManager.open()
        let ftsCount = try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM fts") ?? 0
        }
        XCTAssertEqual(ftsCount, 1)
    }
}
