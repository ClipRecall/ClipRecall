import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ClipRecallCore

/// 正式条目行视图：按主类型渲染六类条目的行布局（TC2.1 第 2 项）。
/// 交互：行主体点击 = 复制召回；悬停浮现固定 / 删除操作按钮。
struct ClipRowView: View {
    let clip: Clip
    let appState: AppState
    var onCopy: ((Clip) -> Void)? = nil
    var onTogglePin: ((Clip) -> Void)? = nil
    var onDelete: ((Clip) -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onCopy?(clip)
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if clip.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button {
                    onTogglePin?(clip)
                } label: {
                    Image(systemName: clip.pinned ? "pin.slash" : "pin")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(clip.pinned ? "取消固定" : "固定")
                Button {
                    onDelete?(clip)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
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
/// 图标解析（尤其 iCloud/网盘文件）可能走远程服务、阻塞主线程——
/// 静态缓存（同一路径/类型只解析一次）+ 后台异步加载 + 占位图标，面板打开零阻塞。
private struct FileIconView: View {
    let clip: Clip
    @State private var icon: NSImage?

    /// 图标缓存（NSCache 线程安全）。
    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Image(nsImage: icon ?? Self.placeholderIcon)
            .resizable()
            .interpolation(.high)
            .frame(width: 20, height: 20)
            .task(id: cacheKey) {
                await loadIcon()
            }
    }

    /// 缓存键：path: 真实文件按路径；type: 文件不存在按扩展名；fallback 通用图标。
    private var cacheKey: String {
        guard let first = clip.formats
            .first(where: { $0.type == FormatUTI.fileURL })?.metadata.files?.first,
              let url = URL(string: first.url)
        else { return "fallback" }
        if FileManager.default.fileExists(atPath: url.path) {
            return "path:\(url.path)"
        }
        return "type:\(url.pathExtension)"
    }

    private func loadIcon() async {
        let key = cacheKey
        if let cached = Self.cache.object(forKey: key as NSString) {
            icon = cached
            return
        }
        icon = nil   // 占位（若行被复用仍持有旧图）
        let resolved = await Task.detached(priority: .userInitiated) {
            Self.resolveIcon(for: key)
        }.value
        guard !Task.isCancelled, let image = resolved?.image else { return }
        Self.cache.setObject(image, forKey: key as NSString)
        icon = image
    }

    /// 解析图标（后台线程调用；NSImage 自 10.6 起只读使用线程安全）。
    nonisolated private static func resolveIcon(for key: String) -> SendableNSImage? {
        if key.hasPrefix("path:") {
            return SendableNSImage(
                image: NSWorkspace.shared.icon(forFile: String(key.dropFirst("path:".count)))
            )
        }
        if key.hasPrefix("type:") {
            let ext = String(key.dropFirst("type:".count))
            let type = UTType(filenameExtension: ext) ?? .data
            return SendableNSImage(image: NSWorkspace.shared.icon(for: type))
        }
        return SendableNSImage(image: NSWorkspace.shared.icon(for: .data))
    }

    private static let placeholderIcon = NSWorkspace.shared.icon(for: .data)
}

/// NSImage 跨并发域传递的封装（只读使用线程安全，见 Apple 文档）。
private struct SendableNSImage: @unchecked Sendable {
    let image: NSImage
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
