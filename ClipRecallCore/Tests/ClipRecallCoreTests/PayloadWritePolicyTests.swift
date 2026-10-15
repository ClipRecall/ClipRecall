import XCTest
@testable import ClipRecallCore

final class PayloadWritePolicyTests: XCTestCase {
    private var tempDirectory: URL!
    private var blobManager: BlobFileManager!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        blobManager = BlobFileManager(directoryURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func inlineFormat(_ data: Data, type: String = FormatUTI.plainText) -> Format {
        Format(type: type, payload: .inline(data))
    }

    func testSmallContentStaysInline() {
        let small = inlineFormat(Data(repeating: 0x41, count: 100))
        let result = PayloadWritePolicy.apply(to: [small], blobManager: blobManager)
        guard case .inline = result[0].payload else {
            return XCTFail("小内容应保持内联")
        }
    }

    func testLargeContentMovesToBlob() throws {
        let data = Data(repeating: 0x42, count: 70 * 1024)
        let result = PayloadWritePolicy.apply(
            to: [inlineFormat(data, type: FormatUTI.png)],
            blobManager: blobManager
        )
        guard case .file(let path) = result[0].payload else {
            return XCTFail("大内容应落盘")
        }
        XCTAssertTrue(path.hasSuffix(".png"))
        XCTAssertEqual(try blobManager.read(relativePath: path), data)
    }

    func testMixedArrayHandledIndependently() throws {
        let small = inlineFormat(Data(repeating: 1, count: 10))
        let large = inlineFormat(Data(repeating: 2, count: 70 * 1024), type: FormatUTI.html)
        let result = PayloadWritePolicy.apply(to: [small, large], blobManager: blobManager)
        guard case .inline = result[0].payload else { return XCTFail("小内容应内联") }
        guard case .file(let path) = result[1].payload else { return XCTFail("大内容应落盘") }
        XCTAssertTrue(path.hasSuffix(".html"))
    }

    func testFileBackedPayloadUntouched() {
        let fileBacked = Format(type: FormatUTI.png, payload: .file(path: "existing.png"))
        let result = PayloadWritePolicy.apply(to: [fileBacked], blobManager: blobManager)
        XCTAssertEqual(result[0], fileBacked)
    }

    func testCustomSmallThreshold() {
        let data = Data(repeating: 3, count: 500)
        let result = PayloadWritePolicy.apply(
            to: [inlineFormat(data)],
            blobManager: blobManager,
            inlineThreshold: 100
        )
        guard case .file = result[0].payload else {
            return XCTFail("自定义小阈值应强制落盘")
        }
    }

    func testWriteFailureDegradesToInline() throws {
        // 用文件占住 blobs 目录位置 → 建目录失败 → 落盘失败 → 降级内联
        let blocked = tempDirectory.appendingPathComponent("blocked")
        try Data("x".utf8).write(to: blocked)
        let failingManager = BlobFileManager(directoryURL: blocked)
        let data = Data(repeating: 4, count: 70 * 1024)
        let result = PayloadWritePolicy.apply(to: [inlineFormat(data)], blobManager: failingManager)
        guard case .inline(let kept) = result[0].payload else {
            return XCTFail("落盘失败应降级为内联")
        }
        XCTAssertEqual(kept.count, data.count)
    }

    func testExtensionMapping() {
        XCTAssertEqual(PayloadWritePolicy.fileExtension(for: FormatUTI.png), "png")
        XCTAssertEqual(PayloadWritePolicy.fileExtension(for: FormatUTI.plainText), "txt")
        XCTAssertEqual(PayloadWritePolicy.fileExtension(for: "public.unknown"), "bin")
    }
}
