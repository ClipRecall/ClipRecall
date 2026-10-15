import Foundation

/// 缩略图生成抽象：输入图片数据，输出缩略图数据（如 PNG）；失败返回 nil。
/// App 层注入 NSImage 实现；测试注入假实现（核心库零平台依赖）。
public protocol ThumbnailGenerating: Sendable {
    /// - Parameters:
    ///   - data: 原始图片数据
    ///   - maxPixelSize: 缩略图最长边像素上限
    func makeThumbnail(from data: Data, maxPixelSize: Int) -> Data?
}

/// 图片缩略图服务：按图片内容指纹磁盘缓存，同一张图只生成一次。
public final class ThumbnailService: @unchecked Sendable {
    private let cacheDirectory: URL
    private let generator: ThumbnailGenerating
    private let maxPixelSize: Int
    private let lock = NSLock()

    /// - Parameters:
    ///   - cacheDirectory: 缓存目录；默认 Application Support/ClipRecall/thumbnails
    ///   - generator: 缩略图生成实现
    ///   - maxPixelSize: 最长边像素上限，默认 128
    public init(
        cacheDirectory: URL? = nil,
        generator: ThumbnailGenerating,
        maxPixelSize: Int = 128
    ) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.cacheDirectory = base
                .appendingPathComponent("ClipRecall", isDirectory: true)
                .appendingPathComponent("thumbnails", isDirectory: true)
        }
        self.generator = generator
        self.maxPixelSize = maxPixelSize
    }

    /// 获取缩略图数据；缓存未命中时生成并落盘。生成失败返回 nil。
    public func thumbnail(for imageData: Data) -> Data? {
        let fileURL = cacheFileURL(for: imageData)
        if let cached = try? Data(contentsOf: fileURL) {
            return cached
        }
        lock.lock()
        defer { lock.unlock() }
        // 双重检查：等锁期间并发请求可能已完成生成
        if let cached = try? Data(contentsOf: fileURL) {
            return cached
        }
        guard let thumbnail = generator.makeThumbnail(from: imageData, maxPixelSize: maxPixelSize) else {
            return nil
        }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? thumbnail.write(to: fileURL, options: .atomic)
        return thumbnail
    }

    /// 缓存文件路径（按图片内容指纹）。
    public func cacheFileURL(for imageData: Data) -> URL {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in imageData {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return cacheDirectory.appendingPathComponent("\(String(hash, radix: 16)).png")
    }
}
