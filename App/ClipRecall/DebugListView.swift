import SwiftUI
import ClipRecallCore

/// 面板：头部（暂停/辅助功能）+ 条目列表（行渲染见 ClipRowView）。
struct DebugListView: View {
    let appState: AppState
    /// 关闭面板的回调（Esc / 点击外部由容器处理）
    var onClose: (() -> Void)? = nil
    @State private var showPermissionGuide = false
    @State private var selectedIndex: Int = 0
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
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(appState.clips.enumerated()), id: \.element.id) { index, clip in
                                    ClipRowView(clip: clip, appState: appState)
                                        .id(clip.id)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.accentColor.opacity(selectedIndex == index ? 0.16 : 0))
                                        )
                                        .onHover { hovering in
                                            if hovering { selectedIndex = index }
                                        }
                                        .onTapGesture {
                                            copyAndClose(clip)
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .frame(width: 320, height: 400)
                        .focusable(true)
                        .focused($isListFocused)
                        .focusEffectDisabled()
                        .onMoveCommand { direction in
                            guard !appState.clips.isEmpty else { return }
                            switch direction {
                            case .up:
                                selectedIndex = max(0, selectedIndex - 1)
                            case .down:
                                selectedIndex = min(appState.clips.count - 1, selectedIndex + 1)
                            default:
                                return
                            }
                            proxy.scrollTo(appState.clips[selectedIndex].id)
                        }
                        .onKeyPress(.return) {
                            guard appState.clips.indices.contains(selectedIndex) else { return .ignored }
                            copyAndClose(appState.clips[selectedIndex])
                            return .handled
                        }
                    }
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
            Button {
                appState.directPasteEnabled.toggle()
            } label: {
                Label(
                    "直接粘贴",
                    systemImage: appState.directPasteEnabled ? "arrow.uturn.right.circle.fill" : "arrow.uturn.right.circle"
                )
            }
            .help("开启后点击/回车自动粘贴到之前的 App；关闭则进剪贴板手动 Cmd+V（默认关闭，T2.6.2 设置页接管）")
            Button {
                appState.plainTextPasteMode.toggle()
            } label: {
                Label(
                    "纯文本",
                    systemImage: appState.plainTextPasteMode ? "doc.plaintext.fill" : "doc.plaintext"
                )
            }
            .help("开启后粘贴剥离格式（纯文本）；关闭则保留原格式（默认关闭，T2.6.2 设置页接管）")
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

    /// 复制选中条目并自动关闭面板（默认行为：进剪贴板、用户手动 Cmd+V；自动粘贴开关见 T2.6.2 明细 ⑤）。
    private func copyAndClose(_ clip: Clip) {
        appState.copyBack(clip)
        onClose?()   // 先关面板释放激活，再执行直接粘贴（若开关开启）
        appState.performDirectPasteIfEnabled()
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
