import XCTest
@testable import ClipRecallCore

final class ClipRecallCoreVersionTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(clipRecallCoreVersion.isEmpty)
    }
}
