import XCTest
@testable import ClipRecallCore

final class ClipContentCaptureTests: XCTestCase {
    private func makePNG(width: UInt32, height: UInt32) -> Data {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += [0x00, 0x00, 0x00, 0x0D]
        bytes += Array("IHDR".utf8)
        bytes += [UInt8(width >> 24 & 0xFF), UInt8(width >> 16 & 0xFF), UInt8(width >> 8 & 0xFF), UInt8(width & 0xFF)]
        bytes += [UInt8(height >> 24 & 0xFF), UInt8(height >> 16 & 0xFF), UInt8(height >> 8 & 0xFF), UInt8(height & 0xFF)]
        return Data(bytes)
    }

    func testWebPageStyleCapturesAllTextForms() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("正文", forType: FormatUTI.plainText)
        pasteboard.setData(Data("<b>正文</b>".utf8), forType: FormatUTI.html)
        pasteboard.setData(Data("rtf".utf8), forType: FormatUTI.rtf)
        let formats = ClipContentCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.map(\.type), [FormatUTI.plainText, FormatUTI.html, FormatUTI.rtf])
    }

    func testMixedTextAndImage() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("看图", forType: FormatUTI.plainText)
        pasteboard.setData(makePNG(width: 10, height: 10), forType: FormatUTI.png)
        let formats = ClipContentCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.map(\.type), [FormatUTI.plainText, FormatUTI.png])
    }

    func testFileOnly() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data("file:///tmp/a.txt\n".utf8), forType: FormatUTI.fileURL)
        let formats = ClipContentCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.map(\.type), [FormatUTI.fileURL])
        XCTAssertEqual(formats[0].metadata.fileCount, 1)
    }

    func testEmptyPasteboardReturnsEmpty() {
        let pasteboard = FakeTextPasteboard()
        XCTAssertTrue(ClipContentCapture.capture(from: pasteboard).isEmpty)
    }

    func testContainsRichText() {
        let plain = [Format(type: FormatUTI.plainText, payload: .inline(Data()))]
        let rich = plain + [Format(type: FormatUTI.html, payload: .inline(Data()))]
        XCTAssertFalse(plain.containsRichText)
        XCTAssertTrue(rich.containsRichText)
    }
}
