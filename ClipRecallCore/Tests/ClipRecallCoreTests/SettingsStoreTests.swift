import XCTest
@testable import ClipRecallCore

final class SettingsStoreTests: XCTestCase {
    private var tempDirectory: URL!
    private var store: SettingsStore!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        store = SettingsStore(databaseManager: DatabaseManager(directoryURL: tempDirectory))
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testSetAndReadRoundTrip() {
        store.set("hello", forKey: "greeting")
        XCTAssertEqual(store.string(forKey: "greeting"), "hello")
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(store.string(forKey: "不存在"))
    }

    func testOverwriteUpdatesValue() {
        store.set("旧值", forKey: "k")
        store.set("新值", forKey: "k")
        XCTAssertEqual(store.string(forKey: "k"), "新值")
    }

    func testRemoveDeletesKey() {
        store.set("值", forKey: "k")
        store.remove(key: "k")
        XCTAssertNil(store.string(forKey: "k"))
    }
}
