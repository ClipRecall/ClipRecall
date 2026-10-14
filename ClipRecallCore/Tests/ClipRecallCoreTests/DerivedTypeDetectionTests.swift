import XCTest
@testable import ClipRecallCore

final class ColorDetectionTests: XCTestCase {
    func testSixDigitHex() {
        let info = ColorDetection.detect(in: "#FF5733")
        XCTAssertEqual(info?.hex, "#FF5733")
        XCTAssertEqual(info?.red, 255)
        XCTAssertEqual(info?.green, 0x57)
        XCTAssertEqual(info?.blue, 0x33)
    }

    func testThreeDigitHexExpands() {
        let info = ColorDetection.detect(in: "#abc")
        XCTAssertEqual(info?.hex, "#AABBCC")
    }

    func testSentenceNotColor() {
        XCTAssertNil(ColorDetection.detect(in: "颜色是 #FF5733"))
    }

    func testInvalidHex() {
        XCTAssertNil(ColorDetection.detect(in: "#G12345"))
        XCTAssertNil(ColorDetection.detect(in: "#12345"))
        XCTAssertNil(ColorDetection.detect(in: "#1234567"))
        XCTAssertNil(ColorDetection.detect(in: ""))
    }
}

final class EmailDetectionTests: XCTestCase {
    func testSimpleEmail() {
        XCTAssertEqual(EmailDetection.detect(in: "foo@bar.com"), "foo@bar.com")
    }

    func testComplexEmail() {
        XCTAssertEqual(
            EmailDetection.detect(in: "user.name+tag@sub.domain.co"),
            "user.name+tag@sub.domain.co"
        )
    }

    func testMissingTLDRejected() {
        XCTAssertNil(EmailDetection.detect(in: "foo@bar"))
    }

    func testSentenceRejected() {
        XCTAssertNil(EmailDetection.detect(in: "我的邮箱是 foo@bar.com"))
    }

    func testShortTLDRejected() {
        XCTAssertNil(EmailDetection.detect(in: "a@b.c"))
    }
}

final class DateDetectionTests: XCTestCase {
    func testISODate() {
        XCTAssertEqual(DateDetection.detect(in: "2024-01-15"), "2024-01-15")
    }

    func testSlashDates() {
        XCTAssertEqual(DateDetection.detect(in: "2024/1/5"), "2024/1/5")
        XCTAssertEqual(DateDetection.detect(in: "1/15/2024"), "1/15/2024")
    }

    func testChineseDate() {
        XCTAssertEqual(DateDetection.detect(in: "2024年1月15日"), "2024年1月15日")
    }

    func testNonDateRejected() {
        XCTAssertNil(DateDetection.detect(in: "今天是个好日子"))
        XCTAssertNil(DateDetection.detect(in: "20240115"))
    }
}
