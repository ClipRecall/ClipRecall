import AppKit
import SwiftUI
import ClipRecallCore

/// AppDelegate：自建状态栏项 + 气泡面板（替换 MenuBarExtra，换取程序化开关能力——
/// 快捷键呼出、弹出定位、焦点控制都依赖它）。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.icon
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.behavior = .transient   // 点击面板外部自动关闭
        popover.contentViewController = NSHostingController(
            rootView: DebugListView(
                appState: appState,
                onClose: { [weak self] in self?.closePopover() },
                onOpenSettings: { [weak self] in self?.openSettings() }
            )
        )

        // 快捷键回调：呼出/收起面板
        appState.onHotkeyPressed = { [weak self] in
            self?.togglePopover()
        }
        // 面板自动关闭：.transient 只在"点击外部"时关闭，键盘切走焦点（Cmd+Tab 等）不触发——
        // 监听前台 App 切换，激活的不是 ClipRecall 自己就收起面板
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  activatedApp.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return }
            self.closePopover()
        }
    }

    /// 打开设置窗口（复用同一个窗口实例）。
    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: SettingsView(appState: appState))
            )
            window.title = "ClipRecall 设置"
            window.styleMask = [.titled, .closable]
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            guard let button = statusItem.button else { return }
            // 记录面板打开前的 App——直接粘贴的目标
            appState.previousApp = NSWorkspace.shared.frontmostApplication
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
