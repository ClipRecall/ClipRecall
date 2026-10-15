import XCTest
@testable import ClipRecallCore

/// 录音机替身：记录收到的变更版本号。
final class RecordingHandler: ClipboardChangeHandling, @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [Int] = []

    var received: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return counts
    }

    func clipboardDidChange(changeCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        counts.append(changeCount)
    }
}

final class ClipboardChangeHandlingTests: XCTestCase {
    private let interval: TimeInterval = 0.05

    private func makeLifecycle(pasteboard: FakePasteboard) -> ClipboardMonitorLifecycle {
        let monitor = PasteboardMonitor(pasteboard: pasteboard, interval: interval)
        return ClipboardMonitorLifecycle(monitor: monitor)
    }

    func testHandlerReceivesChange() {
        let pasteboard = FakePasteboard()
        let lifecycle = makeLifecycle(pasteboard: pasteboard)
        let handler = RecordingHandler()
        lifecycle.start(handler: handler)
        pasteboard.bump()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(handler.received, [1])
        lifecycle.stop()
    }

    func testHandlerReceivesEachChangeInOrder() {
        let pasteboard = FakePasteboard()
        let lifecycle = makeLifecycle(pasteboard: pasteboard)
        let handler = RecordingHandler()
        lifecycle.start(handler: handler)
        for _ in 0..<3 {
            pasteboard.bump()
            Thread.sleep(forTimeInterval: 0.15)
        }
        XCTAssertEqual(handler.received, [1, 2, 3])
        lifecycle.stop()
    }

    func testStopStopsDelivery() {
        let pasteboard = FakePasteboard()
        let lifecycle = makeLifecycle(pasteboard: pasteboard)
        let handler = RecordingHandler()
        lifecycle.start(handler: handler)
        lifecycle.stop()
        pasteboard.bump()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(handler.received.isEmpty)
    }
}
