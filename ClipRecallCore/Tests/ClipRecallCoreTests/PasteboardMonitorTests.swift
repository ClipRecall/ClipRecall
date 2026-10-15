import XCTest
@testable import ClipRecallCore

/// 假剪贴板：测试可手动控制 changeCount（内部有锁保护）。
final class FakePasteboard: PasteboardReading, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func bump() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}

/// XCTestExpectation 的 Sendable 包装（回调在后台队列执行）。
final class ExpectationBox: @unchecked Sendable {
    let expectation: XCTestExpectation
    init(_ expectation: XCTestExpectation) { self.expectation = expectation }
}

/// 值的 Sendable 包装（回调线程写、测试线程读）。
final class IntBox: @unchecked Sendable {
    var value: Int?
    init(_ value: Int? = nil) { self.value = value }
}

final class PasteboardMonitorTests: XCTestCase {
    private let interval: TimeInterval = 0.05

    func testNoCallbackWithoutChange() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let box = ExpectationBox(expectation(description: "无变化不应回调"))
        box.expectation.isInverted = true
        monitor.start { _ in box.expectation.fulfill() }
        wait(for: [box.expectation], timeout: 0.3)
        monitor.stop()
    }

    func testCallbackOnChangeCarriesNewCount() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let received = IntBox()
        let box = ExpectationBox(expectation(description: "变化应回调一次"))
        monitor.start { count in
            received.value = count
            box.expectation.fulfill()
        }
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 1.0)
        XCTAssertEqual(received.value, 1)
        monitor.stop()
    }

    func testEachChangeFiresCallback() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let box = ExpectationBox(expectation(description: "三次变化三次回调"))
        box.expectation.expectedFulfillmentCount = 3
        monitor.start { _ in box.expectation.fulfill() }
        // 间隔足够让每次变化被单独观测到
        pasteboard.bump()
        Thread.sleep(forTimeInterval: 0.15)
        pasteboard.bump()
        Thread.sleep(forTimeInterval: 0.15)
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 1.0)
        monitor.stop()
    }

    func testStartIsIdempotent() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let box = ExpectationBox(expectation(description: "一次变化只回调一次"))
        box.expectation.assertForOverFulfill = true
        monitor.start { _ in box.expectation.fulfill() }
        monitor.start { _ in box.expectation.fulfill() }  // 重复 start 应被忽略
        XCTAssertTrue(monitor.isRunning)
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 1.0)
        monitor.stop()
    }

    func testStopPreventsFurtherCallbacks() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let box = ExpectationBox(expectation(description: "stop 后不应回调"))
        box.expectation.isInverted = true
        monitor.start { _ in box.expectation.fulfill() }
        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 0.3)
    }
}
