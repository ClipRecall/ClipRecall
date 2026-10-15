import XCTest
@testable import ClipRecallCore

final class SensitiveContentDetectionTests: XCTestCase {
    func testCardTrailingMaskDefault() {
        let info = SensitiveContentDetection.detect(in: "1234567890123456")
        XCTAssertEqual(info?.kind, .cardNumber)
        XCTAssertEqual(info?.maskedPreview, "12345678********")
    }

    func testCardLeadingMask() {
        let info = SensitiveContentDetection.detect(
            in: "1234567890123456", maskingRatio: 0.5, maskPosition: .leading
        )
        XCTAssertEqual(info?.maskedPreview, "********90123456")
    }

    func testCardMiddleMask() {
        let info = SensitiveContentDetection.detect(
            in: "1234567890123456", maskingRatio: 0.5, maskPosition: .middle
        )
        // 16 位，遮 8 位：首 4 位 + 尾 4 位可见
        XCTAssertEqual(info?.maskedPreview, "1234********3456")
    }

    func testCardWithSeparatorsMasked() {
        let info = SensitiveContentDetection.detect(in: "1234 5678 9012 3456")
        XCTAssertEqual(info?.kind, .cardNumber)
        XCTAssertEqual(info?.maskedPreview, "1234 5678 *********")
    }

    func testRatioZeroDetectsButDoesNotMask() {
        let info = SensitiveContentDetection.detect(in: "1234567890123456", maskingRatio: 0)
        XCTAssertEqual(info?.kind, .cardNumber)
        XCTAssertEqual(info?.maskedPreview, "1234567890123456")
    }

    func testRatioOneMasksAll() {
        let info = SensitiveContentDetection.detect(in: "1234567890123456", maskingRatio: 1)
        XCTAssertEqual(info?.maskedPreview, "****************")
    }

    func testRatioClamped() {
        let info = SensitiveContentDetection.detect(in: "1234567890123456", maskingRatio: 1.5)
        XCTAssertEqual(info?.maskedPreview, "****************")
    }

    func testAPIKeyDetected() {
        let info = SensitiveContentDetection.detect(in: "sk-abcdefgh12345678")
        XCTAssertEqual(info?.kind, .apiKey)
        // 19 字符，遮 9 位：前 10 字符可见
        XCTAssertEqual(info?.maskedPreview, "sk-abcdefg*********")
    }

    func testPlainTextNotDetected() {
        XCTAssertNil(SensitiveContentDetection.detect(in: "今天天气不错"))
    }

    func testTwelveDigitsNotCard() {
        XCTAssertNil(SensitiveContentDetection.detect(in: "123456789012"))
    }
}
