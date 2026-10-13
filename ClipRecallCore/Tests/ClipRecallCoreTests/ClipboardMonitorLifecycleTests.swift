import XCTest
@testable import ClipRecallCore

final class ClipboardMonitorLifecycleTests: XCTestCase {
    private let interval: TimeInterval = 0.05
    private let wakeName = Notification.Name("test.wake")

    private func makeLifecycle(
        pasteboard: FakePasteboard,
        monitor: PasteboardMonitor
    ) -> ClipboardMonitorLifecycle {
        ClipboardMonitorLifecycle(
            monitor: monitor,
            resumeNotificationNames: [wakeName],
            observerQueue: OperationQueue()
        )
    }

    func testWakeRestartsMonitorAndKeepsWorking() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let lifecycle = makeLifecycle(pasteboard: pasteboard, monitor: monitor)
        let box = ExpectationBox(expectation(description: "唤醒后仍能回调"))
        lifecycle.start { _ in box.expectation.fulfill() }

        NotificationCenter.default.post(name: wakeName, object: nil)
        Thread.sleep(forTimeInterval: 0.2)  // 等唤醒处理完成

        pasteboard.bump()
        wait(for: [box.expectation], timeout: 1.0)
        lifecycle.stop()
    }

    func testStopMakesWakeNoop() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let lifecycle = makeLifecycle(pasteboard: pasteboard, monitor: monitor)
        let box = ExpectationBox(expectation(description: "停止后唤醒无副作用"))
        box.expectation.isInverted = true
        lifecycle.start { _ in box.expectation.fulfill() }
        lifecycle.stop()
        XCTAssertFalse(lifecycle.isRunning)

        NotificationCenter.default.post(name: wakeName, object: nil)
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 0.3)
    }

    func testStartIsIdempotent() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let lifecycle = makeLifecycle(pasteboard: pasteboard, monitor: monitor)
        let box = ExpectationBox(expectation(description: "一次变化只回调一次"))
        box.expectation.assertForOverFulfill = true
        lifecycle.start { _ in box.expectation.fulfill() }
        lifecycle.start { _ in box.expectation.fulfill() }  // 重复 start 应被忽略
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 1.0)
        lifecycle.stop()
    }

    func testWakeWithoutStartIsHarmless() {
        let pasteboard = FakePasteboard()
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        let lifecycle = makeLifecycle(pasteboard: pasteboard, monitor: monitor)
        let box = ExpectationBox(expectation(description: "未启动时唤醒无害"))
        box.expectation.isInverted = true

        NotificationCenter.default.post(name: wakeName, object: nil)
        pasteboard.bump()
        wait(for: [box.expectation], timeout: 0.3)
        XCTAssertFalse(lifecycle.isRunning)
    }
}
