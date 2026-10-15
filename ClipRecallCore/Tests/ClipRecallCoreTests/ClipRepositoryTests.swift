import XCTest
import GRDB
@testable import ClipRecallCore

final class ClipRepositoryTests: XCTestCase {
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

    private func makeClip(_ text: String, type: ClipType = .text) -> Clip {
        Clip(
            primaryType: type,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    func testSaveAndFetchRoundTrip() throws {
        let clip = makeClip("你好世界")
        try repository.save(clip)
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, clip.id)
        XCTAssertEqual(fetched[0].primaryType, .text)
        XCTAssertEqual(fetched[0].textPreview, "你好世界")
        XCTAssertEqual(fetched[0].formats.count, 1)
        XCTAssertEqual(fetched[0].formats[0].type, FormatUTI.plainText)
    }

    func testFetchOrderLatestFirst() throws {
        try repository.save(makeClip("A"))
        Thread.sleep(forTimeInterval: 0.01)
        try repository.save(makeClip("B"))
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.map(\.textPreview), ["B", "A"])
    }

    func testFileBackedPayloadRoundTrip() throws {
        let clip = Clip(
            primaryType: .image,
            formats: [
                Format(
                    type: FormatUTI.png,
                    payload: .file(path: "blobs/abc.png"),
                    metadata: FormatMetadata(pixelSize: PixelSize(width: 10, height: 20))
                )
            ]
        )
        try repository.save(clip)
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].formats[0].payload, .file(path: "blobs/abc.png"))
        XCTAssertEqual(fetched[0].formats[0].metadata.pixelSize, PixelSize(width: 10, height: 20))
    }

    func testUpdateReplacesEntry() throws {
        var clip = makeClip("原始")
        try repository.save(clip)
        clip.pinned = true
        clip.tags = ["重要"]
        try repository.update(clip)
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched[0].pinned)
        XCTAssertEqual(fetched[0].tags, ["重要"])
    }

    func testDeleteTombstones() throws {
        let clip = makeClip("删除我")
        try repository.save(clip)
        try repository.delete(id: clip.id)
        XCTAssertTrue(try repository.fetchRecent(limit: 10).isEmpty)

        // 行仍在，但标记删除（为将来同步保留）
        let manager = DatabaseManager(directoryURL: tempDirectory)
        let pool = try manager.open()
        let count = try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clips WHERE id = ?", arguments: [clip.id.uuidString])
        }
        XCTAssertEqual(count, 1)
    }

    func testSaveMergesContinuation() throws {
        try repository.save(makeClip("前"))
        try repository.save(makeClip("前半段"))
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].textPreview, "前半段")
    }

    func testSaveDeduplicatesAnywhere() throws {
        try repository.save(makeClip("A"))
        try repository.save(makeClip("B"))
        try repository.save(makeClip("A"))
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched.map(\.textPreview), ["A", "B"])
    }

    func testSourceAppRoundTrip() throws {
        let clip = Clip(
            sourceApp: SourceApp(bundleId: "com.apple.Safari", name: "Safari"),
            primaryType: .url,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data("https://example.com".utf8)))],
            textPreview: "https://example.com"
        )
        try repository.save(clip)
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched[0].sourceApp, SourceApp(bundleId: "com.apple.Safari", name: "Safari"))
    }

    func testCodeLanguageMetadataRoundTrip() throws {
        var format = Format(type: FormatUTI.plainText, payload: .inline(Data("def f():\n    print(1)".utf8)))
        format.metadata.codeLanguage = "Python"
        let clip = Clip(primaryType: .code, formats: [format])
        try repository.save(clip)
        let fetched = try repository.fetchRecent(limit: 10)
        XCTAssertEqual(fetched[0].formats[0].metadata.codeLanguage, "Python")
    }
}
