import SwiftUI
import ClipRecallCore

/// 面板：头部（暂停/辅助功能）+ 条目列表（行渲染见 ClipRowView）。
struct DebugListView: View {
    let appState: AppState
    /// 关闭面板的回调（Esc / 点击外部由容器处理）
    var onClose: (() -> Void)? = nil
    @State private var showPermissionGuide = false
    @FocusState private var isListFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if showPermissionGuide, !appState.hasAccessibilityPermission {
                permissionGuide
            }
            Group {
                if appState.clips.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("暂无历史")
                            .font(.headline)
                        Text(appState.isPaused ? "监听已暂停" : "去复制点什么吧")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 300, height: 150)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(appState.clips) { clip in
                                ClipRowView(clip: clip, appState: appState)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(width: 320, height: 400)
                    .focusable(true)
                    .focused($isListFocused)
                    .focusEffectDisabled()
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            isListFocused = true
        }
        .onExitCommand {
            onClose?()
        }
    }

    private var header: some View {
        HStack {
            Button(action: appState.togglePause) {
                Label(
                    appState.isPaused ? "恢复记录" : "暂停记录",
                    systemImage: appState.isPaused ? "play.circle" : "pause.circle"
                )
            }
            Spacer()
            Button {
                showPermissionGuide.toggle()
            } label: {
                Label(
                    "辅助功能",
                    systemImage: appState.hasAccessibilityPermission ? "checkmark.seal" : "exclamationmark.triangle"
                )
            }
            .help(appState.hasAccessibilityPermission ? "辅助功能权限已开启" : "辅助功能权限未开启，点击查看引导")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// 仅未授权时显示的引导卡（授权后自动消失）。
    private var permissionGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("辅助功能权限未开启")
                    .font(.callout)
            }
            Text("直接粘贴功能（阶段 2 上线）需要此权限：允许 ClipRecall 把内容粘贴进其他 App。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("打开系统设置") {
                appState.openAccessibilitySettings()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
