import Foundation

/// 网站图标获取器：直连 https://域名/favicon.ico 下载，磁盘缓存（同一域名只下载一次）。
/// 失败返回 nil（调用方优雅降级）。
/// 隐私注：抓取会把域名发送给对应网站——行业通行做法，将来在隐私政策中明示。
public final class FaviconFetcher: @unchecked Sendable {
    private let cacheDirectory: URL
    private let session: URLSession

    /// - Parameters:
    ///   - cacheDirectory: 缓存目录；默认 Application Support/ClipRecall/favicons
    ///   - session: 自定义网络会话（测试注入假网络层）；nil 时使用 5 秒超时的默认会话
    public init(cacheDirectory: URL? = nil, session: URLSession? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.cacheDirectory = base
                .appendingPathComponent("ClipRecall", isDirectory: true)
                .appendingPathComponent("favicons", isDirectory: true)
        }
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            config.timeoutIntervalForResource = 5
            self.session = URLSession(configuration: config)
        }
    }

    /// 获取域名图标数据；先查缓存，未命中则下载并写缓存。失败返回 nil。
    public func fetch(domain: String) async -> Data? {
        let fileURL = cacheFileURL(for: domain)
        if let cached = try? Data(contentsOf: fileURL) {
            return cached
        }
        guard let url = URL(string: "https://\(domain)/favicon.ico") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            try persist(data, to: fileURL)
            return data
        } catch {
            return nil
        }
    }

    /// 域名对应的缓存文件路径（FNV-1a 哈希文件名，规避域名中的非法字符）。
    public func cacheFileURL(for domain: String) -> URL {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Data(domain.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return cacheDirectory.appendingPathComponent("\(String(hash, radix: 16)).ico")
    }

    private func persist(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
