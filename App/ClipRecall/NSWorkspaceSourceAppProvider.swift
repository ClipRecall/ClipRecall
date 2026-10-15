import AppKit
import ClipRecallCore

/// NSWorkspace 前台应用检测实现。
struct NSWorkspaceSourceAppProvider: SourceAppProviding {
    func frontmostApp() -> FrontmostAppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostAppInfo(
            bundleId: app.bundleIdentifier ?? "",
            name: app.localizedName
        )
    }
}
