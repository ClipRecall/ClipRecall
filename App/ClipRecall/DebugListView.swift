import SwiftUI
import ClipRecallCore

/// 调试列表：显示最近采集的条目，点击复制回剪贴板。
struct DebugListView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.clips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无历史")
                        .font(.headline)
                    Text("去复制点什么吧")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 300, height: 160)
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
        .padding(.vertical, 4)
    }

    private func row(for clip: Clip) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: clip.primaryType))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(previewText(for: clip))
                    .lineLimit(1)
                Text(clip.capturedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func previewText(for clip: Clip) -> String {
        if let textPreview = clip.textPreview, !textPreview.isEmpty {
            return textPreview
        }
        switch clip.primaryType {
        case .image: return "图片"
        case .file: return "文件"
        case .richText: return "富文本"
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
