import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.4.2：语义向量库与余弦检索。
final class SemanticSearchTests: XCTestCase {
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

    private func makeClip(
        _ text: String? = nil, type: ClipType = .text, payload: Data? = nil
    ) -> Clip {
        Clip(
            capturedAt: Date(),
            primaryType: type,
            formats: [
                Format(
                    type: text != nil ? FormatUTI.plainText : FormatUTI.png,
                    payload: .inline(payload ?? Data((text ?? "").utf8))
                )
            ],
            textPreview: text
        )
    }

    private func embeddingCount() throws -> Int {
        let pool = try databaseManager.open()
        return try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM embeddings") ?? 0
        }
    }

    /// 可注入假嵌入器：按文本键返回指定向量（精确控制分数排序）。
    private struct FakeEmbedder: TextEmbedding {
        var vectors: [String: [Double]] = [:]
        func embed(_ text: String) -> [Double]? { vectors[text] }
    }

    func testSaveCreatesEmbeddingRow() throws {
        try repository.save(makeClip("有机票的预订记录"))
        XCTAssertEqual(try embeddingCount(), 1)
        // 图片条目（无文本）不产生向量行
        try repository.save(makeClip(nil, type: .image, payload: Data([0x02])))
        XCTAssertEqual(try embeddingCount(), 1)
    }

    func testSemanticSearchFindsRelatedClip() throws {
        // 真嵌入器冒烟：查询"航班"应把"机票预订信息"排在"苹果香蕉"之前
        let flight = makeClip("机票预订信息", payload: Data([0x01]))
        let fruits = makeClip("苹果香蕉", payload: Data([0x03]))
        try repository.save(flight)
        try repository.save(fruits)
        let hits = try repository.semanticSearch(query: "航班", minScore: 0)
        XCTAssertEqual(hits.first?.clip.id, flight.id)
    }

    func testOCRTextParticipatesInSemanticSearch() throws {
        let image = makeClip(nil, type: .image, payload: Data([0x01]))
        try repository.save(image)
        try repository.setOCRText(clipId: image.id, "机票预订信息")
        let hits = try repository.semanticSearch(query: "航班", minScore: 0)
        XCTAssertEqual(hits.first?.clip.id, image.id)
    }

    func testSoftDeleteRemovesEmbedding() throws {
        let clip = makeClip("有机票的预订记录")
        try repository.save(clip)
        try repository.delete(id: clip.id)
        XCTAssertEqual(try embeddingCount(), 0)
        XCTAssertTrue(try repository.semanticSearch(query: "机票", minScore: 0).isEmpty)
    }

    func testClearAllEmptiesEmbeddings() throws {
        try repository.save(makeClip("条目一", payload: Data([0x01])))
        try repository.save(makeClip("条目二", payload: Data([0x02])))
        _ = try repository.clearAll()
        XCTAssertEqual(try embeddingCount(), 0)
    }

    func testEmptyQueryReturnsEmpty() throws {
        try repository.save(makeClip("有机票的预订记录"))
        XCTAssertTrue(try repository.semanticSearch(query: "").isEmpty)
        XCTAssertTrue(try repository.semanticSearch(query: "   ").isEmpty)
    }

    func testLimitAndScoreOrder() throws {
        let fake = FakeEmbedder(vectors: [
            "文本A": [1, 0],
            "文本B": [0.9, 0.1],
            "文本C": [0.1, 0.9],
            "q": [1, 0],
        ])
        let repo = ClipRepository(databaseManager: databaseManager, embedder: fake)
        let a = makeClip("文本A", payload: Data([0x01]))
        let b = makeClip("文本B", payload: Data([0x02]))
        let c = makeClip("文本C", payload: Data([0x03]))
        try repo.save(a)
        try repo.save(b)
        try repo.save(c)
        let hits = try repo.semanticSearch(query: "q", limit: 2, minScore: 0)
        XCTAssertEqual(hits.map(\.clip.id), [a.id, b.id])
        XCTAssertEqual(hits[0].score, 1.0)
        // Float32 存储有精度损失，用容差断言
        XCTAssertEqual(hits[1].score, 0.9, accuracy: 0.001)
    }

    func testRebuildRestoresEmbeddings() throws {
        try repository.save(makeClip("有机票的预订记录", payload: Data([0x01])))
        try repository.save(makeClip("苹果香蕉", payload: Data([0x02])))
        let pool = try databaseManager.open()
        try pool.write { db in
            try db.execute(sql: "DELETE FROM embeddings")
        }
        XCTAssertEqual(try embeddingCount(), 0)
        _ = try repository.rebuildSearchIndex()
        XCTAssertEqual(try embeddingCount(), 2)
        // 无关条目的余弦可为负值：minScore -1 验证重建后向量完整可检索
        let hits = try repository.semanticSearch(query: "航班", minScore: -1)
        XCTAssertEqual(hits.count, 2)
    }
}
