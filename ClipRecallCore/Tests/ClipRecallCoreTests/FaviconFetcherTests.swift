import XCTest
@testable import ClipRecallCore

/// 假网络层：返回固定数据并计数请求次数。
final class FaviconMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestCount = 0
    nonisolated(unsafe) static var responseData: Data?
    nonisolated(unsafe) static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        if let url = request.url {
            let response = HTTPURLResponse(
                url: url,
                statusCode: Self.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let responseData = Self.responseData {
                client?.urlProtocol(self, didLoad: responseData)
            }
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class FaviconFetcherTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        FaviconMockURLProtocol.requestCount = 0
        FaviconMockURLProtocol.statusCode = 200
        FaviconMockURLProtocol.responseData = Data([0x01, 0x02, 0x03])
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeFetcher() -> FaviconFetcher {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FaviconMockURLProtocol.self]
        let session = URLSession(configuration: config)
        return FaviconFetcher(cacheDirectory: tempDirectory, session: session)
    }

    func testFetchDownloadsAndCaches() async {
        let fetcher = makeFetcher()
        let data = await fetcher.fetch(domain: "example.com")
        XCTAssertEqual(data, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(FaviconMockURLProtocol.requestCount, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fetcher.cacheFileURL(for: "example.com").path)
        )
    }

    func testCacheHitSkipsNetwork() async {
        let fetcher = makeFetcher()
        _ = await fetcher.fetch(domain: "example.com")
        let again = await fetcher.fetch(domain: "example.com")
        XCTAssertEqual(again, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(FaviconMockURLProtocol.requestCount, 1)   // 第二次命中缓存，不再走网络
    }

    func testFailureReturnsNilAndNoCache() async {
        FaviconMockURLProtocol.statusCode = 404
        FaviconMockURLProtocol.responseData = nil
        let fetcher = makeFetcher()
        let data = await fetcher.fetch(domain: "broken.com")
        XCTAssertNil(data)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fetcher.cacheFileURL(for: "broken.com").path)
        )
    }

    func testCacheFileNameIsStable() {
        let fetcher = makeFetcher()
        let first = fetcher.cacheFileURL(for: "github.com")
        let second = fetcher.cacheFileURL(for: "github.com")
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, fetcher.cacheFileURL(for: "apple.com"))
    }
}
