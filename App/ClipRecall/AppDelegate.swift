import AppKit
import SwiftUI
import ClipRecallCore

/// AppDelegate：自建状态栏项 + 气泡面板（替换 MenuBarExtra，换取程序化开关能力——
/// 快捷键呼出、弹出定位、焦点控制都依赖它）。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState()
    private let hotkeyManager = HotkeyManager()
    /// 快捷键设置（T2.6 设置页将读写此结构）
    private var hotkeySettings: HotkeySettings = .default

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
                onClose: { [weak self] in self?.closePopover() }
            )
        )

        // 全局快捷键：Option+` 呼出/收起面板
        hotkeyManager.register(hotkeySettings) { [weak self] in
            self?.togglePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
