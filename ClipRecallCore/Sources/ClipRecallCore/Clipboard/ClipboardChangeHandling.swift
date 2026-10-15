import Foundation

/// 剪贴板变更消费协议：采集器等消费者实现此协议接收变更事件。
/// 回调可能在后台队列执行。
public protocol ClipboardChangeHandling: Sendable {
    /// 剪贴板内容变化时调用；changeCount 为最新版本号。
    func clipboardDidChange(changeCount: Int)
}

extension ClipboardMonitorLifecycle {
    /// 以协议形式开始监听：为采集器提供的标准入口。
    public func start(handler: ClipboardChangeHandling) {
        start { count in
            handler.clipboardDidChange(changeCount: count)
        }
    }
}
