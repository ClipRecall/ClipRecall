import XCTest
@testable import ClipRecallCore

final class URLDetectionTests: XCTestCase {
    func testHTTPSWithPathAndQuery() {
        let info = URLDetection.detect(in: "https://github.com/groue/GRDB.swift?tab=readme")
        XCTAssertEqual(info?.domain, "github.com")
    }

    func testHTTPSimpleURL() {
        let info = URLDetection.detect(in: "http://example.com")
        XCTAssertEqual(info?.domain, "example.com")
    }

    func testWWWPrefixStripsWWW() {
        let info = URLDetection.detect(in: "www.github.com/path")
        XCTAssertEqual(info?.domain, "github.com")
    }

    func testBareDomain() {
        let info = URLDetection.detect(in: "apple.com")
        XCTAssertEqual(info?.domain, "apple.com")
    }

    func testNumericTLDRejected() {
        XCTAssertNil(URLDetection.detect(in: "1.2"))
    }

    func testMultiLineTextRejected() {
        XCTAssertNil(URLDetection.detect(in: "第一行\nhttps://example.com"))
    }

    func testSentenceContainingURLRejected() {
        XCTAssertNil(URLDetection.detect(in: "请看这个网址 https://example.com 谢谢"))
    }

    func testEmptyTextRejected() {
        XCTAssertNil(URLDetection.detect(in: "   "))
    }

    func testIPAddressURLAccepted() {
        let info = URLDetection.detect(in: "https://192.168.1.1/admin")
        XCTAssertEqual(info?.domain, "192.168.1.1")
    }
}
