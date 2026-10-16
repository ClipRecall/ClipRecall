import AppKit
import SwiftUI
import ClipRecallCore

/// 面板：头部（暂停/辅助功能）+ 条目列表（行渲染见 ClipRowView）。
struct DebugListView: View {
    let appState: AppState
    /// 关闭面板的回调（Esc / 点击外部由容器处理）
    var onClose: (() -> Void)? = nil
    /// 打开设置窗口的回调
    var onOpenSettings: (() -> Void)? = nil
    @State private var showPermissionGuide = false
    @State private var selectedIndex: Int = 0
    @State private var multiSelected: [UUID] = []   // 多选（按选择顺序）
    @State private var pendingDelete: Clip?
    @State private var showClearAllAlert = false
    @State private var showQuitAlert = false
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
                                    ClipRowView(
                                        clip: clip,
                                        appState: appState,
                                        onCopy: { handleRowClick($0) },
                                        onTogglePin: { appState.togglePin($0) },
                                        onDelete: { pendingDelete = $0 }
                                    )
                                    .id(clip.id)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.accentColor.opacity(selectedIndex == index ? 0.16 : 0))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.accentColor, lineWidth: 1.5)
                                            .opacity(multiSelected.contains(clip.id) ? 1 : 0)
                                    )
                                    .onHover { hovering in
                                        if hovering { selectedIndex = index }
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
                            if !multiSelected.isEmpty {
                                mergeSelectedAndClose()
                                return .handled
                            }
                            guard appState.clips.indices.contains(selectedIndex) else { return .ignored }
                            copyAndClose(appState.clips[selectedIndex])
                            return .handled
                        }
                    }
                }
            }
            footer
        }
        .padding(.vertical, 4)
        .onAppear {
            isListFocused = true
        }
        .onExitCommand {
            if !multiSelected.isEmpty {
                multiSelected.removeAll()   // Esc 先退出多选
            } else {
                onClose?()
            }
        }
        .alert(
            "删除该条目？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let clip = pendingDelete {
                    appState.deleteClip(clip)
                    pendingDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete.map { "「\($0.textPreview ?? "")」删除后不可恢复。" } ?? "")
        }
        .alert("清空全部历史？", isPresented: $showClearAllAlert) {
            Button("清空", role: .destructive) {
                appState.clearAllHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除全部 \(appState.clips.count) 条历史，此操作不可撤销。")
        }
        .alert("确认退出 ClipRecall？", isPresented: $showQuitAlert) {
            Button("退出", role: .destructive) {
                NSApp.terminate(nil)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后将停止记录剪贴板历史。")
        }
    }

    /// 底部栏：条目计数 + 清空 + 退出。
    private var footer: some View {
        HStack {
            Text("\(appState.clips.count) 条")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("清空") {
                showClearAllAlert = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            Button("退出") {
                showQuitAlert = true
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: appState.togglePause) {
                Image(systemName: appState.isPaused ? "play.circle" : "pause.circle")
            }
            .help(appState.isPaused ? "恢复记录" : "暂停记录")
            Button {
                appState.setDirectPaste(!appState.directPasteEnabled)
            } label: {
                Image(systemName: appState.directPasteEnabled ? "arrow.uturn.right.circle.fill" : "arrow.uturn.right.circle")
            }
            .help("直接粘贴：开启后点击/回车自动粘贴到之前的 App；关闭则进剪贴板手动 Cmd+V（默认关闭）")
            Button {
                appState.setPlainTextMode(!appState.plainTextPasteMode)
            } label: {
                Image(systemName: appState.plainTextPasteMode ? "doc.plaintext.fill" : "doc.plaintext")
            }
            .help("纯文本粘贴：开启后剥离格式；关闭则保留原格式（默认关闭）")
            Button {
                onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("设置")
            Spacer()
            Button {
                showPermissionGuide.toggle()
            } label: {
                Image(systemName: appState.hasAccessibilityPermission ? "checkmark.seal" : "exclamationmark.triangle")
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

    /// 行点击：⌘点击 = 切换多选；普通点击 = 单条复制（并清空多选）。
    private func handleRowClick(_ clip: Clip) {
        if NSEvent.modifierFlags.contains(.command) {
            toggleMultiSelect(clip)
        } else {
            multiSelected.removeAll()
            copyAndClose(clip)
        }
    }

    private func toggleMultiSelect(_ clip: Clip) {
        if let index = multiSelected.firstIndex(of: clip.id) {
            multiSelected.remove(at: index)
        } else {
            multiSelected.append(clip.id)
        }
    }

    /// 按选择顺序合并复制多选项并关闭面板。
    private func mergeSelectedAndClose() {
        let clips = multiSelected.compactMap { id in
            appState.clips.first { $0.id == id }
        }
        multiSelected.removeAll()
        appState.mergeAndCopy(clips)
        onClose?()
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
