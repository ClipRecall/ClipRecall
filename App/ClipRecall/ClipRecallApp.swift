import AppKit
import SwiftUI
import ClipRecallCore

@main
struct ClipRecallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        Log.info("ClipRecall 启动，Core v\(clipRecallCoreVersion)")
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
