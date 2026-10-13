import XCTest
@testable import ClipRecallCore

final class ClipModelTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func testClipRoundTripWithAllFields() {
        let clip = Clip(
            id: UUID(),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceApp: SourceApp(bundleId: "com.apple.Safari", name: "Safari"),
            primaryType: .url,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data("hello".utf8)))],
            textPreview: "hello",
            pinned: true,
            tags: ["重要"],
            groupId: UUID(),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            isDeleted: false
        )
        XCTAssertEqual(roundTrip(clip), clip)
    }

    func testClipRoundTripWithDefaults() {
        let clip = Clip(primaryType: .text, formats: [])
        XCTAssertEqual(roundTrip(clip), clip)
        XCTAssertFalse(clip.pinned)
        XCTAssertTrue(clip.tags.isEmpty)
        XCTAssertNil(clip.groupId)
        XCTAssertFalse(clip.isDeleted)
    }

    func testClipIdentifiableUsesId() {
        let id = UUID()
        let clip = Clip(id: id, primaryType: .text, formats: [])
        XCTAssertEqual(clip.id, id)
    }
}

final class FormatModelTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func testInlinePayloadRoundTrip() {
        let format = Format(type: FormatUTI.plainText, payload: .inline(Data("hello".utf8)))
        XCTAssertEqual(roundTrip(format), format)
    }

    func testFilePayloadRoundTrip() {
        let format = Format(
            type: FormatUTI.png,
            payload: .file(path: "blobs/abc.png"),
            metadata: FormatMetadata(pixelSize: PixelSize(width: 100, height: 200))
        )
        XCTAssertEqual(roundTrip(format), format)
    }

    func testIsInlineAndIsFileBacked() {
        let inline = Format(type: FormatUTI.plainText, payload: .inline(Data()))
        let file = Format(type: FormatUTI.png, payload: .file(path: "blobs/a.png"))
        XCTAssertTrue(inline.isInline)
        XCTAssertFalse(inline.isFileBacked)
        XCTAssertTrue(file.isFileBacked)
        XCTAssertFalse(file.isInline)
    }

    func testDefaultVersionIsOne() {
        let format = Format(type: FormatUTI.plainText, payload: .inline(Data()))
        XCTAssertEqual(format.version, 1)
    }
}

final class FormatUTITests: XCTestCase {
    func testValuesAreCorrect() {
        XCTAssertEqual(FormatUTI.plainText, "public.utf8-plain-text")
        XCTAssertEqual(FormatUTI.html, "public.html")
        XCTAssertEqual(FormatUTI.rtf, "public.rtf")
        XCTAssertEqual(FormatUTI.png, "public.png")
        XCTAssertEqual(FormatUTI.tiff, "public.tiff")
        XCTAssertEqual(FormatUTI.fileURL, "public.file-url")
    }

    func testValuesAreNotEmpty() {
        let all = [
            FormatUTI.plainText, FormatUTI.html, FormatUTI.rtf,
            FormatUTI.png, FormatUTI.tiff, FormatUTI.fileURL,
        ]
        for uti in all {
            XCTAssertFalse(uti.isEmpty)
        }
    }
}
