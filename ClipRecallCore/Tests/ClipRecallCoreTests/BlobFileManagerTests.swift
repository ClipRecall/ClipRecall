import XCTest
@testable import ClipRecallCore

final class BlobFileManagerTests: XCTestCase {
    private var tempDirectory: URL!
    private var manager: BlobFileManager!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        manager = BlobFileManager(directoryURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testWriteThenReadRoundTrip() throws {
        let data = Data("hello blob".utf8)
        let path = try manager.write(data, fileExtension: "png")
        XCTAssertEqual(try manager.read(relativePath: path), data)
    }

    func testWriteCreatesNestedDirectory() throws {
        let nested = tempDirectory.appendingPathComponent("x/y", isDirectory: true)
        let nestedManager = BlobFileManager(directoryURL: nested)
        let path = try nestedManager.write(Data([1, 2, 3]), fileExtension: "bin")
        XCTAssertEqual(try nestedManager.read(relativePath: path), Data([1, 2, 3]))
    }

    func testGeneratedPathsAreUnique() throws {
        let a = try manager.write(Data("a".utf8), fileExtension: "png")
        let b = try manager.write(Data("b".utf8), fileExtension: "png")
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.hasSuffix(".png"))
    }

    func testReadNonexistentThrows() {
        XCTAssertThrowsError(try manager.read(relativePath: "missing.bin"))
    }

    func testDeleteRemovesFile() throws {
        let path = try manager.write(Data("x".utf8), fileExtension: "txt")
        try manager.delete(relativePath: path)
        XCTAssertThrowsError(try manager.read(relativePath: path))
    }

    func testDeleteNonexistentThrows() {
        XCTAssertThrowsError(try manager.delete(relativePath: "missing.bin"))
    }

    func testRejectsTraversalPaths() {
        for bad in ["../secret.txt", "a/b.txt", "..", ".", ""] {
            XCTAssertThrowsError(try manager.read(relativePath: bad), "应拒绝路径：\(bad)")
            XCTAssertThrowsError(try manager.delete(relativePath: bad), "应拒绝路径：\(bad)")
        }
    }

    func testExtensionSanitization() {
        let a = manager.makeRelativePath(fileExtension: ".png")
        let b = manager.makeRelativePath(fileExtension: "png")
        let c = manager.makeRelativePath(fileExtension: "")
        XCTAssertTrue(a.hasSuffix(".png"))
        XCTAssertTrue(b.hasSuffix(".png"))
        XCTAssertTrue(c.hasSuffix(".bin"))
    }
}
