import AppKit
import ApplicationServices
import ClipRecallCore

/// 直接粘贴：向当前激活的 App 发送 Cmd+V 系统级键盘事件。
/// 需要辅助功能权限（AXIsProcessTrusted）；无权限返回 false，调用方降级为"进剪贴板手动粘贴"。
struct DirectPastePerformer {
    /// 发送一次 Cmd+V；无权限返回 false。
    /// - Parameter pid: 目标进程 ID；提供时事件直投该进程（不依赖焦点），否则发系统级事件。
    @discardableResult
    func performPaste(to pid: pid_t? = nil) -> Bool {
        guard AXIsProcessTrusted() else {
            Log.warning("直接粘贴需要辅助功能权限，已降级为剪贴板+手动粘贴", module: .app)
            return false
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)   // kVK_ANSI_V
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        if let pid {
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
        } else {
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
        return true
    }
}
