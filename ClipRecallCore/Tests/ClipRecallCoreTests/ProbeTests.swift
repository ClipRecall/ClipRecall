import XCTest
@testable import ClipRecallCore

final class ProbeTests: XCTestCase {
    func testProbe() throws {
        let embedder = TextEmbedder()
        let clipText = "合肥到杭州 直飞 海南航空 1000元 商务舱"
        guard let clipVec = embedder.embed(clipText) else {
            print("PROBE clipText 嵌入为 nil"); return
        }
        for query in ["机票", "航班", "飞机", "飞机票", "出行", "旅游"] {
            guard let q = embedder.embed(query) else {
                print("PROBE \"\(query)\" 嵌入为 nil"); continue
            }
            let score = zip(q, clipVec).reduce(0) { $0 + $1.0 * $1.1 }
            print("PROBE \"\(query)\" vs clipText ->", score)
        }
        print("PROBE clipVec 前5维:", Array(clipVec.prefix(5)))
    }
}
