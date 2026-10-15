import XCTest
@testable import ClipRecallCore

/// 假生成器：返回固定数据并计数。
final class FakeThumbnailGenerator: ThumbnailGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    var result: Data?

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func makeThumbnail(from data: Data, maxPixelSize: Int) -> Data? {
        lock.lock()
        calls += 1
        lock.unlock()
        return result
    }
}

final class ThumbnailServiceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
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

    private func makeService(generator: FakeThumbnailGenerator) -> ThumbnailService {
        ThumbnailService(cacheDirectory: tempDirectory, generator: generator)
    }

    func testFirstCallGeneratesAndCaches() {
        let generator = FakeThumbnailGenerator()
        generator.result = Data([0xAA, 0xBB])
        let service = makeService(generator: generator)
        let image = Data("图片A".utf8)

        XCTAssertEqual(service.thumbnail(for: image), Data([0xAA, 0xBB]))
        XCTAssertEqual(generator.callCount, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: service.cacheFileURL(for: image).path)
        )
    }

    func testSecondCallHitsCache() {
        let generator = FakeThumbnailGenerator()
        generator.result = Data([0xAA, 0xBB])
        let service = makeService(generator: generator)
        let image = Data("图片A".utf8)

        _ = service.thumbnail(for: image)
        let again = service.thumbnail(for: image)
        XCTAssertEqual(again, Data([0xAA, 0xBB]))
        XCTAssertEqual(generator.callCount, 1)   // 第二次命中缓存，生成器不再被调
    }

    func testDifferentImagesSeparateCache() {
        let generator = FakeThumbnailGenerator()
        generator.result = Data([0xAA, 0xBB])
        let service = makeService(generator: generator)

        _ = service.thumbnail(for: Data("图片A".utf8))
        _ = service.thumbnail(for: Data("图片B".utf8))
        XCTAssertEqual(generator.callCount, 2)
    }

    func testFailureReturnsNilWithoutCache() {
        let generator = FakeThumbnailGenerator()
        generator.result = nil
        let service = makeService(generator: generator)
        let image = Data("坏图片".utf8)

        XCTAssertNil(service.thumbnail(for: image))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: service.cacheFileURL(for: image).path)
        )
    }
}
