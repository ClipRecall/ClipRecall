import XCTest
@testable import ClipRecallCore

final class FileCaptureTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func fileURLString(_ fileName: String) -> String {
        URL(fileURLWithPath: tempDirectory.appendingPathComponent(fileName).path).absoluteString
    }

    private func makeFile(_ name: String, content: String) throws -> String {
        let url = tempDirectory.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        return URL(fileURLWithPath: url.path).absoluteString
    }

    func testCapturesFilesWithNameAndSize() throws {
        let fileA = try makeFile("a.txt", content: "hello")
        let fileB = try makeFile("b.txt", content: "world!!")
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data("\(fileA)\n\(fileB)\n".utf8), forType: FormatUTI.fileURL)

        let formats = FileCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.count, 1)
        XCTAssertEqual(formats[0].type, FormatUTI.fileURL)
        XCTAssertEqual(formats[0].metadata.fileCount, 2)
        let files = try XCTUnwrap(formats[0].metadata.files)
        XCTAssertEqual(files.map(\.name), ["a.txt", "b.txt"])
        XCTAssertEqual(files[0].size, 5)   // "hello".utf8.count == 5
        XCTAssertEqual(files[1].size, 7)   // "world!!".utf8.count == 7
    }

    func testMissingFileKeepsReferenceWithNilSize() {
        let missingURL = fileURLString("gone.txt")
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data("\(missingURL)\n".utf8), forType: FormatUTI.fileURL)

        let formats = FileCapture.capture(from: pasteboard)
        let files = formats[0].metadata.files
        XCTAssertEqual(files?.count, 1)
        XCTAssertEqual(files?[0].name, "gone.txt")
        XCTAssertNil(files?[0].size)
    }

    func testDirectoryHasNilSize() {
        let dirURL = URL(fileURLWithPath: tempDirectory.path).absoluteString
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data("\(dirURL)\n".utf8), forType: FormatUTI.fileURL)

        let formats = FileCapture.capture(from: pasteboard)
        let files = formats[0].metadata.files
        XCTAssertEqual(files?.count, 1)
        XCTAssertNil(files?[0].size)
    }

    func testGarbageDataReturnsEmpty() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data("这不是地址".utf8), forType: FormatUTI.fileURL)
        XCTAssertTrue(FileCapture.capture(from: pasteboard).isEmpty)
    }

    func testNoFileURLTypeReturnsEmpty() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("plain", forType: FormatUTI.plainText)
        XCTAssertTrue(FileCapture.capture(from: pasteboard).isEmpty)
    }

    func testMetadataRoundTripWithFiles() throws {
        let reference = FileReference(url: "file:///tmp/a.txt", name: "a.txt", size: 123)
        let metadata = FormatMetadata(fileCount: 1, files: [reference])
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(FormatMetadata.self, from: data)
        XCTAssertEqual(decoded, metadata)
    }
}
