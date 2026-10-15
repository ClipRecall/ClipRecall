import AppKit
import SwiftUI
import ClipRecallCore

@main
struct ClipRecallApp: App {
    @State private var appState = AppState()

    init() {
        // 启动即打开数据库（自动建目录、建表）；失败不阻塞界面
        _ = try? DatabaseManager.shared.open()
        Log.info("ClipRecall 启动，Core v\(clipRecallCoreVersion)")
    }

    var body: some Scene {
        MenuBarExtra {
            DebugListView(appState: appState)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// 自定义菜单栏图标（模板图，自动适配深/浅色菜单栏）。
    private static var menuBarIcon: NSImage {
        let image = NSImage(named: "menubar-icon") ?? NSImage(systemSymbolName: "clipboard", accessibilityDescription: nil)!
        image.isTemplate = true
        return image
    }
}
