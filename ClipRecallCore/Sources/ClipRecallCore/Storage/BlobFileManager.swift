import Foundation

/// blobs 目录文件管理器：大内容的磁盘存放间（architecture 4.2 的落盘路径）。
/// 相对路径语义：仅存放间内的文件名（不含目录前缀）。
public final class BlobFileManager: @unchecked Sendable {
    public static let shared = BlobFileManager()

    private let blobsDirectoryURL: URL

    /// - Parameter directoryURL: blobs 目录；默认 Application Support/ClipRecall/blobs。
    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            blobsDirectoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            blobsDirectoryURL = base
                .appendingPathComponent("ClipRecall", isDirectory: true)
                .appendingPathComponent("blobs", isDirectory: true)
        }
    }

    /// blobs 目录完整路径
    public var directoryURL: URL { blobsDirectoryURL }

    /// 生成一个全新的 blob 文件名（相对路径）。扩展名自动消毒。
    public func makeRelativePath(fileExtension: String) -> String {
        "\(UUID().uuidString).\(Self.sanitizedExtension(fileExtension))"
    }

    /// 写入 blob，返回相对路径。
    public func write(_ data: Data, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
        let relativePath = makeRelativePath(fileExtension: fileExtension)
        let url = blobsDirectoryURL.appendingPathComponent(relativePath)
        try data.write(to: url, options: .atomic)
        return relativePath
    }

    /// 读取 blob。
    public func read(relativePath: String) throws -> Data {
        let url = try validatedURL(relativePath)
        return try Data(contentsOf: url)
    }

    /// 删除 blob；文件不存在时报错。
    public func delete(relativePath: String) throws {
        let url = try validatedURL(relativePath)
        try FileManager.default.removeItem(at: url)
    }

    /// 校验并解析相对路径：只接受纯文件名，拒绝含目录成分或越界的路径。
    private func validatedURL(_ relativePath: String) throws -> URL {
        let isPlainFileName = relativePath == (relativePath as NSString).lastPathComponent
        guard !relativePath.isEmpty,
              relativePath != ".",
              relativePath != "..",
              isPlainFileName
        else {
            throw BlobError.invalidRelativePath(relativePath)
        }
        return blobsDirectoryURL.appendingPathComponent(relativePath)
    }

    /// 扩展名消毒：去掉前导点、仅保留字母数字、空则用 bin、最长 16 字符。
    private static func sanitizedExtension(_ fileExtension: String) -> String {
        let trimmed = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let filtered = trimmed.filter { $0.isLetter || $0.isNumber }
        return filtered.isEmpty ? "bin" : String(filtered.prefix(16))
    }
}

/// blob 文件操作错误。
public enum BlobError: Error {
    /// 相对路径非法（含目录成分或越界）
    case invalidRelativePath(String)
}
