import Foundation

/// 剪贴板哨兵：按固定间隔轮询 changeCount，内容变化时触发回调。
/// - 首次观测作为基线，不触发回调——只有启动之后的变化才回调；
/// - 重复 start 幂等（保持原回调）；
/// - stop 后不再回调；回调在内部后台队列上执行。
public final class PasteboardMonitor: @unchecked Sendable {
    private let pasteboard: PasteboardReading
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var lastCount: Int?

    /// - Parameters:
    ///   - pasteboard: 剪贴板读取实现
    ///   - interval: 轮询间隔（秒），默认 0.5
    public init(pasteboard: PasteboardReading, interval: TimeInterval = 0.5) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.queue = DispatchQueue(label: "com.andromeda.ClipRecall.pasteboard-monitor")
    }

    deinit {
        timer?.cancel()
    }

    /// 是否正在监听
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timer != nil
    }

    /// 开始监听。回调携带新的 changeCount。
    public func start(onChange: @escaping @Sendable (Int) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else {
            Log.warning("PasteboardMonitor 已在运行，忽略重复 start", module: .clipboard)
            return
        }
        lastCount = pasteboard.changeCount
        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(50))
        newTimer.setEventHandler { [weak self] in
            self?.tick(onChange: onChange)
        }
        timer = newTimer
        newTimer.resume()
    }

    /// 停止监听。
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
        lastCount = nil
    }

    private func tick(onChange: @escaping @Sendable (Int) -> Void) {
        let current = pasteboard.changeCount
        lock.lock()
        let previous = lastCount
        if previous != current {
            lastCount = current
        }
        lock.unlock()
        if let previous, previous != current {
            onChange(current)
        }
    }
}
