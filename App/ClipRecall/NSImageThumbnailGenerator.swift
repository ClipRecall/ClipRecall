import AppKit
import ClipRecallCore

/// NSImage 缩略图生成器（AppKit 实现）：缩放到最长边 maxPixelSize 内，输出 PNG。
struct NSImageThumbnailGenerator: ThumbnailGenerating {
    func makeThumbnail(from data: Data, maxPixelSize: Int) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let longest = max(size.width, size.height)
        let scale = min(1.0, Double(maxPixelSize) / longest)
        let target = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: target)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target))
        thumbnail.unlockFocus()

        guard let tiff = thumbnail.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }
}
