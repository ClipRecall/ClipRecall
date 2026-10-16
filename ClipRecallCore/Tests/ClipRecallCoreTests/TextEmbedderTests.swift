import XCTest
@testable import ClipRecallCore

/// T3.4.1：NLEmbedding 文本向量化。
final class TextEmbedderTests: XCTestCase {
    private let embedder = TextEmbedder()

    func testEnglishEmbeddingNonEmpty() throws {
        let vector = try XCTUnwrap(embedder.embed("airplane ticket booking"))
        XCTAssertFalse(vector.isEmpty)
    }

    func testChineseEmbeddingNonEmpty() throws {
        let vector = try XCTUnwrap(embedder.embed("机票预订信息"))
        XCTAssertFalse(vector.isEmpty)
    }

    func testSemanticSimilaritySmoke() throws {
        // 词级相关性冒烟：同主题词的相似度应高于无关词
        let flight = try XCTUnwrap(embedder.embed("机票航班"))
        let booking = try XCTUnwrap(embedder.embed("预订航班信息"))
        let fruits = try XCTUnwrap(embedder.embed("苹果香蕉"))
        XCTAssertGreaterThan(cosine(flight, booking), cosine(flight, fruits))
    }

    func testEmptyTextReturnsNil() {
        XCTAssertNil(embedder.embed(""))
        XCTAssertNil(embedder.embed("   "))
    }

    func testSymbolOnlyTextReturnsNil() {
        // 无有效词（纯符号）：分词后无词向量 → nil
        XCTAssertNil(embedder.embed("… … …"))
    }

    func testVectorIsNormalized() throws {
        let vector = try XCTUnwrap(embedder.embed("normalization check"))
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        XCTAssertEqual(norm, 1.0, accuracy: 0.001)
    }

    /// 归一化向量点积 = 余弦相似度。
    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
