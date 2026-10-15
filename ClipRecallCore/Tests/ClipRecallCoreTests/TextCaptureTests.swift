import XCTest
@testable import ClipRecallCore

/// 字典式假剪贴板：可任意设定类型与内容。
final class FakeTextPasteboard: PasteboardReading, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var strings: [String: String] = [:]
    private var count = 0

    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var types: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(Set(storage.keys).union(strings.keys))
    }

    func data(forType type: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[type]
    }

    func string(forType type: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return strings[type]
    }

    func setString(_ string: String, forType type: String) {
        lock.lock()
        defer { lock.unlock() }
        strings[type] = string
    }

    func setData(_ data: Data, forType type: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[type] = data
    }
}

final class TextCaptureTests: XCTestCase {
    func testCapturesPlainTextOnly() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("你好, clipboard", forType: FormatUTI.plainText)
        let formats = TextCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.count, 1)
        XCTAssertEqual(formats[0].type, FormatUTI.plainText)
        guard case .inline(let data) = formats[0].payload else {
            return XCTFail("应为内联载荷")
        }
        XCTAssertEqual(String(data: data, encoding: .utf8), "你好, clipboard")
    }

    func testCapturesAllThreeFormsInOrder() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("纯文本", forType: FormatUTI.plainText)
        pasteboard.setData(Data("<b>加粗</b>".utf8), forType: FormatUTI.html)
        pasteboard.setData(Data("rtf-data".utf8), forType: FormatUTI.rtf)
        let formats = TextCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.map(\.type), [FormatUTI.plainText, FormatUTI.html, FormatUTI.rtf])
    }

    func testReturnsEmptyWhenNoTextForms() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: FormatUTI.png)
        XCTAssertTrue(TextCapture.capture(from: pasteboard).isEmpty)
    }

    func testChineseRoundTrip() {
        let pasteboard = FakeTextPasteboard()
        let original = "中文混排 hello 123，含 emoji 🎉"
        pasteboard.setString(original, forType: FormatUTI.plainText)
        let formats = TextCapture.capture(from: pasteboard)
        guard case .inline(let data) = formats[0].payload else {
            return XCTFail("应为内联载荷")
        }
        XCTAssertEqual(String(data: data, encoding: .utf8), original)
    }
}
