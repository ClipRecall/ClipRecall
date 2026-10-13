import SwiftUI
import ClipRecallCore

@main
struct ClipRecallApp: App {
    init() {
        // 启动即打开数据库（自动建目录、建表）；失败不阻塞界面
        _ = try? DatabaseManager.shared.open()
        Log.info("ClipRecall 启动，Core v\(clipRecallCoreVersion)")
    }

    var body: some Scene {
        MenuBarExtra("ClipRecall", systemImage: "clipboard") {
            VStack(spacing: 8) {
                Image(systemName: "clipboard")
                    .font(.largeTitle)
                Text("ClipRecall")
                    .font(.headline)
                Text("空壳版本：功能开发中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Core v\(clipRecallCoreVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}
