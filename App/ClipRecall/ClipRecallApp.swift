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
        MenuBarExtra("ClipRecall", systemImage: "clipboard") {
            DebugListView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}
