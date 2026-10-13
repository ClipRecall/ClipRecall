import XCTest
@testable import ClipRecallCore

final class ClipTypeTests: XCTestCase {
    func testAllSevenCasesExist() {
        XCTAssertEqual(ClipType.allCases.count, 7)
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(ClipType.text.rawValue, "text")
        XCTAssertEqual(ClipType.richText.rawValue, "richText")
        XCTAssertEqual(ClipType.image.rawValue, "image")
        XCTAssertEqual(ClipType.file.rawValue, "file")
        XCTAssertEqual(ClipType.url.rawValue, "url")
        XCTAssertEqual(ClipType.code.rawValue, "code")
        XCTAssertEqual(ClipType.color.rawValue, "color")
    }

    func testRawValueRoundTrip() {
        for type in ClipType.allCases {
            XCTAssertEqual(ClipType(rawValue: type.rawValue), type)
        }
    }
}

final class SourceAppTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(
            SourceApp(bundleId: "com.apple.Safari", name: "Safari"),
            SourceApp(bundleId: "com.apple.Safari", name: "Safari")
        )
        XCTAssertNotEqual(
            SourceApp(bundleId: "com.apple.Safari", name: "Safari"),
            SourceApp(bundleId: "com.apple.Safari", name: "Chrome")
        )
    }
}

final class CodableRoundTripTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func testSourceAppRoundTrip() {
        let app = SourceApp(bundleId: "com.apple.Safari", name: "Safari")
        XCTAssertEqual(roundTrip(app), app)
    }

    func testFormatMetadataRoundTripWithAllFields() {
        let metadata = FormatMetadata(
            pixelSize: PixelSize(width: 1920, height: 1080),
            fileCount: 3,
            codeLanguage: "Swift"
        )
        XCTAssertEqual(roundTrip(metadata), metadata)
    }

    func testFormatMetadataRoundTripWithNoFields() {
        let metadata = FormatMetadata()
        XCTAssertEqual(roundTrip(metadata), metadata)
    }

    func testPixelSizeRoundTrip() {
        let size = PixelSize(width: 300, height: 200)
        XCTAssertEqual(roundTrip(size), size)
    }
}
