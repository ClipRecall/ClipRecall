import XCTest
@testable import ClipRecallCore

final class RecentClipsStoreTests: XCTestCase {
    private func makeClip(_ text: String) -> Clip {
        Clip(
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    func testLatestFirstOrder() {
        let store = RecentClipsStore(limit: 10)
        store.append(makeClip("第一条"))
        store.append(makeClip("第二条"))
        store.append(makeClip("第三条"))
        XCTAssertEqual(store.clips.map(\.textPreview), ["第三条", "第二条", "第一条"])
    }

    func testLimitTrimsOldest() {
        let store = RecentClipsStore(limit: 3)
        for index in 1...5 {
            store.append(makeClip("第\(index)条"))
        }
        XCTAssertEqual(store.clips.count, 3)
        XCTAssertEqual(store.clips.map(\.textPreview), ["第5条", "第4条", "第3条"])
    }

    func testOnAppendCallbackFires() {
        let store = RecentClipsStore(limit: 10)
        let box = IntBox()
        store.onAppend = { _ in
            box.value = 1
        }
        store.append(makeClip("触发"))
        XCTAssertEqual(box.value, 1)
    }
}
