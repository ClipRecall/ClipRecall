import XCTest
@testable import ClipRecallCore

final class ClipTypeInferenceTests: XCTestCase {
    private func formats(_ types: String...) -> [Format] {
        types.map { Format(type: $0, payload: .inline(Data())) }
    }

    func testPlainTextInfersText() {
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.plainText)), .text)
    }

    func testHTMLInfersRichText() {
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.html)), .richText)
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.rtf)), .richText)
    }

    func testImageInfersImage() {
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.png)), .image)
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.tiff)), .image)
    }

    func testFileURLInfersFile() {
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats(FormatUTI.fileURL)), .file)
    }

    func testEmptyFormatsDefaultToText() {
        XCTAssertEqual(ClipTypeInference.primaryType(from: []), .text)
    }

    func testMixedTextImageInfersImage() {
        // 图文混合（如截图）：图片优先
        let mixed = formats(FormatUTI.plainText, FormatUTI.png)
        XCTAssertEqual(ClipTypeInference.primaryType(from: mixed), .image)
    }
}
