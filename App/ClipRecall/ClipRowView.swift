import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ClipRecallCore

/// 正式条目行视图：按主类型渲染六类条目的行布局（TC2.1 第 2 项）。
struct ClipRowView: View {
    let clip: Clip
    let appState: AppState

    var body: some View {
        Button {
            appState.copyBack(clip)
        } label: {
            HStack(spacing: 10) {
                leadingIcon
                VStack(alignment: .leading, spacing: 3) {
                    primaryText
                        .lineLimit(clip.primaryType == .url ? nil : 1)
                    Text(captionText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 主文本

    @ViewBuilder
    private var primaryText: some View {
        switch clip.primaryType {
        case .color:
            Text(colorHex)
                .font(.system(.body, design: .monospaced))
        case .code:
            Text(previewOrTypeName)
                .font(.system(.body, design: .monospaced))
        case .image:
            Text("图片")
        case .file:
            Text(fileSummary)
        default:
            Text(previewOrTypeName)
        }
    }

    // MARK: - 角标

    private var captionText: String {
        let time = clip.capturedAt.formatted(date: .omitted, time: .shortened)
        switch clip.primaryType {
        case .image:
            if let pixelSize = firstImageFormat?.metadata.pixelSize {
                return "图片 · \(pixelSize.width)×\(pixelSize.height) · \(time)"
            }
            return "图片 · \(time)"
        case .file:
            let count = clip.formats.first(where: { $0.type == FormatUTI.fileURL })?.metadata.fileCount
            if let count, count > 1 {
                return "文件 · \(count) 个 · \(time)"
            }
            return "文件 · \(time)"
        case .code:
            if let language = firstPlainFormat?.metadata.codeLanguage {
                return "\(language) · \(time)"
            }
            return "代码 · \(time)"
        case .url:
            return "链接 · \(time)"
        case .color:
            return "颜色 · \(time)"
        case .richText:
            return "富文本 · \(time)"
        case .text:
            if let kind = firstPlainFormat?.metadata.sensitiveKind {
                return "\(sensitiveLabel(kind)) · \(time)"
            }
            if let preview = clip.textPreview {
                if EmailDetection.detect(in: preview) != nil { return "邮箱 · \(time)" }
                if DateDetection.detect(in: preview) != nil { return "日期 · \(time)" }
            }
            return "文本 · \(time)"
        }
    }

    // MARK: - 图标

    @ViewBuilder
    private var leadingIcon: some View {
        if firstPlainFormat?.metadata.sensitiveKind != nil {
            icon("eye.slash")
        } else {
            switch clip.primaryType {
            case .color:
                ColorSwatchView(clip: clip)
            case .image:
                ThumbnailView(clip: clip, appState: appState)
            case .url:
                if let preview = clip.textPreview, let info = URLDetection.detect(in: preview) {
                    FaviconView(domain: info.domain, fetcher: appState.faviconFetcher)
                } else {
                    icon("link")
                }
            case .code:
                icon("chevron.left.forwardslash.chevron.right")
            case .file:
                FileIconView(clip: clip)
            case .richText:
                icon("doc.richtext")
            default:
                icon("doc.text")
            }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .foregroundStyle(.secondary)
            .frame(width: 20)
    }

    // MARK: - 辅助

    private var firstPlainFormat: Format? {
        clip.formats.first(where: { $0.type == FormatUTI.plainText })
    }

    private var firstImageFormat: Format? {
        clip.formats.first(where: { $0.type == FormatUTI.png || $0.type == FormatUTI.tiff })
    }

    private var previewOrTypeName: String {
        if let preview = clip.textPreview, !preview.isEmpty { return preview }
        switch clip.primaryType {
        case .image: return "图片"
        case .file: return "文件"
        case .richText: return "富文本"
        case .url: return "链接"
        default: return "（空内容）"
        }
    }

    private var colorHex: String {
        if let preview = clip.textPreview,
           let info = ColorDetection.detect(in: preview) {
            return info.hex
        }
        return clip.textPreview ?? "#000000"
    }

    private var fileSummary: String {
        guard let files = clip.formats.first(where: { $0.type == FormatUTI.fileURL })?.metadata.files,
              let first = files.first
        else { return "文件" }
        if files.count > 1 {
            return "\(first.name) 等 \(files.count) 个文件"
        }
        return first.name
    }

    private func sensitiveLabel(_ kind: SensitiveKind) -> String {
        switch kind {
        case .cardNumber: return "银行卡号"
        case .apiKey: return "APIKey"
        }
    }
}

// MARK: - 子视图

/// 文件条目图标：文件存在时取其真实图标，不存在时按扩展名取类型图标。
private struct FileIconView: View {
    let clip: Clip

    var body: some View {
        Image(nsImage: resolvedIcon)
            .resizable()
            .interpolation(.high)
            .frame(width: 20, height: 20)
    }

    private var resolvedIcon: NSImage {
        guard let first = clip.formats
            .first(where: { $0.type == FormatUTI.fileURL })?.metadata.files?.first,
              let url = URL(string: first.url)
        else {
            return NSWorkspace.shared.icon(for: .data)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: type)
    }
}

/// 颜色条目色块。
private struct ColorSwatchView: View {
    let clip: Clip

    var body: some View {
        Circle()
            .fill(resolvedColor)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
    }

    private var resolvedColor: Color {
        guard let preview = clip.textPreview,
              let info = ColorDetection.detect(in: preview)
        else { return .gray }
        return Color(
            red: Double(info.red) / 255,
            green: Double(info.green) / 255,
            blue: Double(info.blue) / 255
        )
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
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
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
