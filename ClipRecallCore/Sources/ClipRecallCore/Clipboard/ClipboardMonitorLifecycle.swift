import Foundation

/// 剪贴板监听管家：管理哨兵的启动 / 停止与睡眠唤醒恢复。
/// - 唤醒通知名由外部注入（App 层传入系统唤醒通知，核心库保持零平台依赖）；
/// - 收到唤醒通知时重启哨兵：睡眠期间剪贴板不会变化，重置基线无损；
/// - 重复 start 幂等；stop 后注销全部观察者，唤醒通知不再生效。
public final class ClipboardMonitorLifecycle: @unchecked Sendable {
    private let monitor: PasteboardMonitor
    private let resumeNotificationNames: [Notification.Name]
    private let observerQueue: OperationQueue?
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var onChange: (@Sendable (Int) -> Void)?

    /// - Parameters:
    ///   - monitor: 被管理的哨兵
    ///   - resumeNotificationNames: 视为"唤醒/恢复"的系统通知名
    ///   - observerQueue: 唤醒恢复处理的执行队列；nil 时为通知发送线程
    public init(
        monitor: PasteboardMonitor,
        resumeNotificationNames: [Notification.Name] = [],
        observerQueue: OperationQueue? = nil
    ) {
        self.monitor = monitor
        self.resumeNotificationNames = resumeNotificationNames
        self.observerQueue = observerQueue
    }

    deinit {
        removeObservers()
    }

    /// 是否正在管理
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return onChange != nil
    }

    /// 开始管理：启动哨兵并注册唤醒通知。
    public func start(onChange: @escaping @Sendable (Int) -> Void) {
        lock.lock()
        guard self.onChange == nil else {
            lock.unlock()
            Log.warning("ClipboardMonitorLifecycle 已在运行，忽略重复 start", module: .clipboard)
            return
        }
        self.onChange = onChange
        lock.unlock()

        monitor.start(onChange: onChange)
        registerResumeObservers()
    }

    /// 停止管理：停止哨兵并注销全部观察者。
    public func stop() {
        lock.lock()
        onChange = nil
        lock.unlock()
        monitor.stop()
        removeObservers()
    }

    private func registerResumeObservers() {
        lock.lock()
        defer { lock.unlock() }
        for name in resumeNotificationNames {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: observerQueue
            ) { [weak self] _ in
                self?.handleResume()
            }
            observers.append(token)
        }
    }

    private func removeObservers() {
        lock.lock()
        let tokens = observers
        observers = []
        lock.unlock()
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// 唤醒恢复：重启哨兵（重新设定基线）。
    private func handleResume() {
        lock.lock()
        let callback = onChange
        lock.unlock()
        guard let callback else { return }
        monitor.stop()
        monitor.start(onChange: callback)
        Log.info("检测到唤醒通知，剪贴板哨兵已重启", module: .clipboard)
    }
}
