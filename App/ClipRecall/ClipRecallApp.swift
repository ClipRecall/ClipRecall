import SwiftUI

@main
struct ClipRecallApp: App {
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
            }
            .padding()
        }
    }
}
