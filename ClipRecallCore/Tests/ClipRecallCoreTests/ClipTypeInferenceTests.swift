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

    func testPlainURLInfersURL() {
        let formats = [Format(type: FormatUTI.plainText, payload: .inline(Data("https://example.com".utf8)))]
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats), .url)
    }

    func testSentenceWithURLStaysText() {
        let formats = [Format(type: FormatUTI.plainText, payload: .inline(Data("请看 https://example.com".utf8)))]
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats), .text)
    }

    func testColorValueInfersColor() {
        let formats = [Format(type: FormatUTI.plainText, payload: .inline(Data("#FF5733".utf8)))]
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats), .color)
    }

    func testEmailNotMisdetectedAsURL() {
        // 回归：邮箱先于 URL 检测，foo@bar.com 不应被判为网址
        let formats = [Format(type: FormatUTI.plainText, payload: .inline(Data("foo@bar.com".utf8)))]
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats), .text)
    }

    func testDerivedTypeBeatsRichText() {
        // 回归：带 HTML 的颜色值/网址/代码仍应识别为对应派生类型（用户实测发现富文本截胡）
        let colorFormats = [
            Format(type: FormatUTI.plainText, payload: .inline(Data("#FF5733".utf8))),
            Format(type: FormatUTI.html, payload: .inline(Data("<b>#FF5733</b>".utf8))),
        ]
        XCTAssertEqual(ClipTypeInference.primaryType(from: colorFormats), .color)

        let urlFormats = [
            Format(type: FormatUTI.plainText, payload: .inline(Data("https://example.com".utf8))),
            Format(type: FormatUTI.html, payload: .inline(Data("<a>链接</a>".utf8))),
        ]
        XCTAssertEqual(ClipTypeInference.primaryType(from: urlFormats), .url)
    }

    func testPlainParagraphWithHTMLStaysRichText() {
        // 普通段落（不匹配任何派生模式）+ HTML → 仍是富文本
        let formats = [
            Format(type: FormatUTI.plainText, payload: .inline(Data("带格式的普通段落".utf8))),
            Format(type: FormatUTI.html, payload: .inline(Data("<b>带格式的普通段落</b>".utf8))),
        ]
        XCTAssertEqual(ClipTypeInference.primaryType(from: formats), .richText)
    }
}
