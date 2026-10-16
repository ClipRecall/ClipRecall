import XCTest
@testable import ClipRecallCore

final class ClipMergingTests: XCTestCase {
    private func textClip(_ text: String) -> Clip {
        Clip(
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    func testMergesInOrderWithNewlines() {
        let result = ClipMerging.mergedText(from: [textClip("姓名"), textClip("电话"), textClip("地址")])
        XCTAssertEqual(result, "姓名\n电话\n地址")
    }

    func testSkipsEntriesWithoutPlainText() {
        let image = Clip(
            primaryType: .image,
            formats: [Format(type: FormatUTI.png, payload: .inline(Data([0x89])))]
        )
        let result = ClipMerging.mergedText(from: [textClip("A"), image, textClip("B")])
        XCTAssertEqual(result, "A\nB")
    }

    func testEmptyResultReturnsNil() {
        let image = Clip(
            primaryType: .image,
            formats: [Format(type: FormatUTI.png, payload: .inline(Data([0x89])))]
        )
        XCTAssertNil(ClipMerging.mergedText(from: [image]))
        XCTAssertNil(ClipMerging.mergedText(from: []))
    }
}
