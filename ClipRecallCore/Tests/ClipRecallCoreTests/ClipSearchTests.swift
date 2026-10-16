import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.1.2：全文搜索查询接口（FTS5 短语匹配 + 中文/符号 LIKE 兜底）。
final class ClipSearchTests: XCTestCase {
    private var tempDirectory: URL!
    private var repository: ClipRepository!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        let manager = DatabaseManager(directoryURL: tempDirectory)
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

    func testEnglishWordSearch() throws {
        try repository.save(makeClip("hello alpha world"))
        try repository.save(makeClip("goodbye beta"))
        let hits = try repository.search("alpha")
        XCTAssertEqual(hits.map(\.textPreview), ["hello alpha world"])
    }

    func testEnglishCaseInsensitive() throws {
        try repository.save(makeClip("Hello World"))
        XCTAssertEqual(try repository.search("HELLO").count, 1)
        XCTAssertEqual(try repository.search("hello").count, 1)
    }

    func testEnglishPhraseMatchesInOrder() throws {
        try repository.save(makeClip("quick brown fox"))
        XCTAssertEqual(try repository.search("brown fox").count, 1)
        // 顺序颠倒不是短语命中
        XCTAssertTrue(try repository.search("fox brown").isEmpty)
    }

    func testChineseExactMatch() throws {
        try repository.save(makeClip("今天的会议记录"))
        try repository.save(makeClip("明天的日程安排"))
        let hits = try repository.search("会议")
        XCTAssertEqual(hits.map(\.textPreview), ["今天的会议记录"])
    }

    func testChineseQueryWithPunctuation() throws {
        // TC3.1 分词案例观察点：unicode61 把全角标点（，）当作词元而非分隔符，
        // 因此查询必须带上标点才能短语命中；不带标点时不命中（文本中确有标点，子串不成立）
        try repository.save(makeClip("搜索，历史记录"))
        XCTAssertEqual(try repository.search("搜索，历史").count, 1)
        XCTAssertEqual(try repository.search("搜索历史").count, 0)
    }

    func testSymbolQueryFallsBackToLike() throws {
        // 纯符号查询：FTS 分词为空短语会报语法错误 → 走 LIKE 兜底
        try repository.save(makeClip("①②③号文件"))
        try repository.save(makeClip("普通文本"))
        let hits = try repository.search("①②")
        XCTAssertEqual(hits.map(\.textPreview), ["①②③号文件"])
    }

    func testEmptyAndWhitespaceQueryReturnsEmpty() throws {
        try repository.save(makeClip("anything"))
        XCTAssertTrue(try repository.search("").isEmpty)
        XCTAssertTrue(try repository.search("   ").isEmpty)
    }

    func testSpecialCharactersDoNotCrash() throws {
        try repository.save(makeClip("C++ code with \"quotes\" and *stars*"))
        // 含 FTS 特殊字符的查询：不抛错即可（命中与否均可接受）
        XCTAssertNoThrow(try repository.search("C++*"))
        XCTAssertNoThrow(try repository.search("a \"quoted\" b"))
    }

    func testDeletedClipIsNotSearchable() throws {
        let clip = makeClip("unique kangaroo")
        try repository.save(clip)
        try repository.delete(id: clip.id)
        XCTAssertTrue(try repository.search("kangaroo").isEmpty)
    }

    func testLimitAndNewestFirstOrder() throws {
        let base = Date()
        try repository.save(makeClip("common oldest", capturedAt: base.addingTimeInterval(-20)))
        try repository.save(makeClip("common middle", capturedAt: base.addingTimeInterval(-10)))
        try repository.save(makeClip("common newest", capturedAt: base))
        let hits = try repository.search("common", limit: 2)
        XCTAssertEqual(hits.map(\.textPreview), ["common newest", "common middle"])
    }
}
