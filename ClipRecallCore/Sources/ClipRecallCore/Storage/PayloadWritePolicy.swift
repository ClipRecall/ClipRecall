import Foundation

/// Payload 写入策略：按大小阈值决定内容内联存储或落盘到 blobs 目录。
public enum PayloadWritePolicy {
    /// 内联存储的上限（字节）；超过则落盘。默认 64KB。
    public static let defaultInlineThreshold = 64 * 1024

    /// 对格式包执行写入策略：
    /// - 内联内容超过阈值 → 写入 blobs，载荷替换为 .file（相对路径）；
    /// - 落盘失败时优雅降级：保持内联，记警告日志，不丢数据；
    /// - 已是 .file 的载荷不动（幂等安全）。
    public static func apply(
        to formats: [Format],
        blobManager: BlobFileManager,
        inlineThreshold: Int = defaultInlineThreshold
    ) -> [Format] {
        formats.map { format in
            guard case .inline(let data) = format.payload else { return format }
            guard data.count > inlineThreshold else { return format }
            do {
                let relativePath = try blobManager.write(data, fileExtension: fileExtension(for: format.type))
                var updated = format
                updated.payload = .file(path: relativePath)
                return updated
            } catch {
                Log.warning("blob 写入失败（\(error)），保持内联存储", module: .storage)
                return format
            }
        }
    }

    /// 按格式类型映射落盘文件扩展名。
    static func fileExtension(for type: String) -> String {
        switch type {
        case FormatUTI.png: return "png"
        case FormatUTI.tiff: return "tiff"
        case FormatUTI.html: return "html"
        case FormatUTI.rtf: return "rtf"
        case FormatUTI.plainText: return "txt"
        default: return "bin"
        }
    }
}
