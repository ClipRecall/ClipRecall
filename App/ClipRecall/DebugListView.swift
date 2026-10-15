import AppKit
import SwiftUI
import ClipRecallCore

/// 调试列表：显示最近采集的条目，点击复制回剪贴板。
struct DebugListView: View {
    let appState: AppState

    @State private var showPermissionGuide = false

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
                                Button {
                                    appState.copyBack(clip)
                                } label: {
                                    row(for: clip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(width: 320, height: 400)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack {
            Button(action: appState.togglePause) {
                Label(
                    appState.isPaused ? "恢复记录" : "暂停记录",
                    systemImage: appState.isPaused ? "play.circle" : "pause.circle"
                )
            }
            Button("测试数据") {
                appState.seedTestData()
            }
            .help("生成 5000 条测试数据（重启后自动清理回默认上限）")
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

    private func row(for clip: Clip) -> some View {
        HStack(spacing: 8) {
            leadingIcon(for: clip)
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: clip))
                    .lineLimit(clip.primaryType == .url ? nil : 1)
                Text(captionText(for: clip))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func leadingIcon(for clip: Clip) -> some View {
        if clip.formats.first(where: { $0.type == FormatUTI.plainText })?.metadata.sensitiveKind != nil {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .frame(width: 18)
        } else if clip.primaryType == .color,
           let preview = clip.textPreview,
           let info = ColorDetection.detect(in: preview) {
            Circle()
                .fill(
                    Color(
                        red: Double(info.red) / 255,
                        green: Double(info.green) / 255,
                        blue: Double(info.blue) / 255
                    )
                )
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
        } else if clip.primaryType == .image {
            ThumbnailView(clip: clip, appState: appState)
        } else if clip.primaryType == .url,
                  let preview = clip.textPreview,
                  let info = URLDetection.detect(in: preview) {
            FaviconView(domain: info.domain, fetcher: appState.faviconFetcher)
        } else {
            Image(systemName: iconName(for: clip.primaryType))
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
    }

    /// 统一的"类型 · 时间"角标。
    private func captionText(for clip: Clip) -> String {
        let time = clip.capturedAt.formatted(date: .omitted, time: .shortened)
        let label: String
        switch clip.primaryType {
        case .code:
            if let plain = clip.formats.first(where: { $0.type == FormatUTI.plainText }),
               let language = plain.metadata.codeLanguage {
                label = language
            } else {
                label = "代码"
            }
        case .text:
            if let plain = clip.formats.first(where: { $0.type == FormatUTI.plainText }),
               let kind = plain.metadata.sensitiveKind {
                label = sensitiveLabel(kind)
            } else if let preview = clip.textPreview {
                if EmailDetection.detect(in: preview) != nil {
                    label = "邮箱"
                } else if DateDetection.detect(in: preview) != nil {
                    label = "日期"
                } else {
                    label = "文本"
                }
            } else {
                label = "文本"
            }
        default:
            label = typeName(clip.primaryType)
        }
        return "\(label) · \(time)"
    }

    private func typeName(_ type: ClipType) -> String {
        switch type {
        case .text: return "文本"
        case .richText: return "富文本"
        case .image: return "图片"
        case .file: return "文件"
        case .url: return "链接"
        case .code: return "代码"
        case .color: return "颜色"
        }
    }

    private func sensitiveLabel(_ kind: SensitiveKind) -> String {
        switch kind {
        case .cardNumber: return "银行卡号"
        case .apiKey: return "APIKey"
        }
    }

    private func previewText(for clip: Clip) -> String {
        // 链接条目显示完整网址（域名仍用于图标获取与识别）
        if let textPreview = clip.textPreview, !textPreview.isEmpty {
            return textPreview
        }
        switch clip.primaryType {
        case .image: return "图片"
        case .file: return "文件"
        case .richText: return "富文本"
        case .url: return "链接"
        default: return "（空内容）"
        }
    }

    private func iconName(for type: ClipType) -> String {
        switch type {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        }
    }
}

/// 图片缩略图视图：异步加载，失败时显示默认图片图标。
private struct ThumbnailView: View {
    let clip: Clip
    let appState: AppState
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .task(id: clip.id) {
            imageData = await appState.thumbnail(for: clip)
        }
    }
}

/// 网站图标视图：异步加载，失败时显示默认链接图标。
private struct FaviconView: View {
    let domain: String
    let fetcher: FaviconFetcher
    @State private var imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
        }
        .task(id: domain) {
            imageData = await fetcher.fetch(domain: domain)
        }
    }
}
