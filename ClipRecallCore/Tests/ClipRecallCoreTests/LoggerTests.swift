import XCTest
@testable import ClipRecallCore

final class LoggerTests: XCTestCase {
    func testSubsystemIsExpected() {
        XCTAssertEqual(Log.subsystem, "com.andromeda.ClipRecall")
    }

    func testModuleCategoriesAreStable() {
        XCTAssertEqual(LogModule.app.rawValue, "app")
        XCTAssertEqual(LogModule.models.rawValue, "models")
        XCTAssertEqual(LogModule.clipboard.rawValue, "clipboard")
        XCTAssertEqual(LogModule.storage.rawValue, "storage")
        XCTAssertEqual(LogModule.search.rawValue, "search")
        XCTAssertEqual(LogModule.ai.rawValue, "ai")
        XCTAssertEqual(LogModule.sync.rawValue, "sync")
        XCTAssertEqual(LogModule.diagnostics.rawValue, "diagnostics")
    }

    func testAllLevelsSmokeNoCrash() {
        Log.debug("debug 冒烟")
        Log.info("info 冒烟")
        Log.warning("warning 冒烟")
        Log.error("error 冒烟")
        for module in LogModule.allCases {
            Log.info("模块冒烟", module: module)
        }
    }
}
