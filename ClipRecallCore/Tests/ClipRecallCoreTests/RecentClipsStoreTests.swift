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

    func testSameContentRefreshesInsteadOfDuplicating() {
        let store = RecentClipsStore(limit: 10)
        store.append(makeClip("相同内容"))
        Thread.sleep(forTimeInterval: 0.01)   // 确保时间可区分
        let second = makeClip("相同内容")
        store.append(second)
        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].capturedAt, second.capturedAt)
    }

    func testSameContentThenDifferentAppends() {
        let store = RecentClipsStore(limit: 10)
        store.append(makeClip("A"))
        store.append(makeClip("A"))   // 去重刷新
        store.append(makeClip("B"))
        XCTAssertEqual(store.clips.map(\.textPreview), ["B", "A"])
    }

    func testDuplicateAnywhereMovesToFront() {
        // A → B → A：A 不在最新位置，仍应去重并置顶
        let store = RecentClipsStore(limit: 10)
        store.append(makeClip("A"))
        store.append(makeClip("B"))
        store.append(makeClip("A"))
        XCTAssertEqual(store.clips.map(\.textPreview), ["A", "B"])
    }

    func testSameTextWithDifferentFormatsDeduplicates() {
        // 回归：系统异步补格式导致格式包形态不同（如第二次多了 HTML），仍应去重
        let store = RecentClipsStore(limit: 10)
        let first = Clip(
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data("相同".utf8)))],
            textPreview: "相同"
        )
        let second = Clip(
            primaryType: .richText,
            formats: [
                Format(type: FormatUTI.plainText, payload: .inline(Data("相同".utf8))),
                Format(type: FormatUTI.html, payload: .inline(Data("<b>相同</b>".utf8))),
            ],
            textPreview: "相同"
        )
        store.append(first)
        store.append(second)
        XCTAssertEqual(store.clips.count, 1)
    }
}
