import XCTest
@testable import ClipRecallCore

final class DatabaseManagerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testOpenCreatesDatabaseFile() throws {
        let manager = DatabaseManager(directoryURL: tempDirectory)
        _ = try manager.open()
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.databaseURL.path))
    }

    func testOpenIsIdempotent() throws {
        let manager = DatabaseManager(directoryURL: tempDirectory)
        let first = try manager.open()
        let second = try manager.open()
        XCTAssertTrue(first === second)
    }

    func testOpenCreatesNestedDirectories() throws {
        let nested = tempDirectory.appendingPathComponent("a/b/c", isDirectory: true)
        let manager = DatabaseManager(directoryURL: nested)
        _ = try manager.open()
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.databaseURL.path))
    }

    func testDatabaseURLUsesExpectedFileName() {
        let manager = DatabaseManager(directoryURL: tempDirectory)
        XCTAssertEqual(manager.databaseURL.lastPathComponent, "cliprecall.sqlite")
    }
}
