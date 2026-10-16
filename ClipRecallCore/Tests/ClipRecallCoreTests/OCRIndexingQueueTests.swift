import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.3.2：增量 OCR 索引队列（待处理选取、载荷读取、单步处理、失败标记）。
final class OCRIndexingQueueTests: XCTestCase {
    private var tempDirectory: URL!
    private var databaseManager: DatabaseManager!
    private var repository: ClipRepository!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        let manager = DatabaseManager(directoryURL: tempDirectory)
        databaseManager = manager
        repository = ClipRepository(databaseManager: manager)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    /// 测试假识别器：可注入成功文本或抛错。
    private struct FakeRecognizer: ImageTextRecognizing {
        var result: Result<String, Error> = .success("识别文本")
        func recognizeText(in imageData: Data) throws -> String {
            try result.get()
        }
    }

    private enum TestError: Error { case boom }

    private func makeImageClip(_ capturedAt: Date = Date(), payload: Payload = .inline(Data([0x01, 0x02]))) -> Clip {
        Clip(
            capturedAt: capturedAt,
            primaryType: .image,
            formats: [Format(type: FormatUTI.png, payload: payload)]
        )
    }

    private func makeTextClip(_ text: String) -> Clip {
        Clip(
            capturedAt: Date(),
            primaryType: .text,
            formats: [Format(type: FormatUTI.plainText, payload: .inline(Data(text.utf8)))],
            textPreview: text
        )
    }

    private func storedOCRText(clipId: UUID) throws -> String? {
        let pool = try databaseManager.open()
        return try pool.read { db in
            try String.fetchOne(
                db, sql: "SELECT ocrText FROM clips WHERE id = ?", arguments: [clipId.uuidString]
            )
        }
    }

    func testNextOCRClipOnlyPicksImageUnprocessed() throws {
        try repository.save(makeTextClip("纯文本不参与 OCR"))
        // 载荷不同避免被去重替换
        let oldImage = makeImageClip(
            Date().addingTimeInterval(-100), payload: .inline(Data([0x01]))
        )
        let newImage = makeImageClip(Date(), payload: .inline(Data([0x02])))
        try repository.save(oldImage)
        try repository.save(newImage)
        // 最旧优先
        XCTAssertEqual(try repository.nextOCRClipID(), oldImage.id)
        // 标记完成后跳过
        try repository.setOCRText(clipId: oldImage.id, "已有文本")
        XCTAssertEqual(try repository.nextOCRClipID(), newImage.id)
        // 全部完成 → nil
        try repository.setOCRText(clipId: newImage.id, "")
        XCTAssertNil(try repository.nextOCRClipID())
    }

    func testNextOCRClipSkipsSoftDeleted() throws {
        let clip = makeImageClip()
        try repository.save(clip)
        try repository.delete(id: clip.id)
        XCTAssertNil(try repository.nextOCRClipID())
    }

    func testImagePayloadInlineRead() throws {
        let data = Data([0xAB, 0xCD, 0xEF])
        let clip = makeImageClip(payload: .inline(data))
        try repository.save(clip)
        XCTAssertEqual(try repository.imagePayloadData(clipId: clip.id), data)
    }

    func testImagePayloadFromFileRead() throws {
        let blobManager = BlobFileManager(
            directoryURL: tempDirectory.appendingPathComponent("blobs", isDirectory: true)
        )
        let repo = ClipRepository(
            databaseManager: databaseManager, blobManager: blobManager
        )
        let data = Data(repeating: 0x77, count: 64)
        let path = try blobManager.write(data, fileExtension: "png")
        let clip = Clip(
            capturedAt: Date(),
            primaryType: .image,
            formats: [Format(type: FormatUTI.png, payload: .file(path: path))]
        )
        try repo.save(clip)
        XCTAssertEqual(try repo.imagePayloadData(clipId: clip.id), data)
    }

    func testProcessOneClipEndToEnd() async throws {
        let clip = makeImageClip()
        try repository.save(clip)
        let queue = OCRIndexingQueue(
            repository: repository, recognizer: FakeRecognizer()
        )
        let processed = try await queue.processOneClip()
        XCTAssertTrue(processed)
        XCTAssertEqual(try storedOCRText(clipId: clip.id), "识别文本")
        // 已处理 → 没有更多待办
        let again = try await queue.processOneClip()
        XCTAssertFalse(again)
    }

    func testProcessOneClipFailureMarksDone() async throws {
        let clip = makeImageClip()
        try repository.save(clip)
        var failing = FakeRecognizer()
        failing.result = .failure(TestError.boom)
        let queue = OCRIndexingQueue(repository: repository, recognizer: failing)
        let processed = try await queue.processOneClip()
        XCTAssertTrue(processed)
        // 失败也标记完成（空文本），不重复重试
        XCTAssertEqual(try storedOCRText(clipId: clip.id), "")
        XCTAssertNil(try repository.nextOCRClipID())
    }

    func testProcessOneClipNoPendingReturnsFalse() async throws {
        let queue = OCRIndexingQueue(
            repository: repository, recognizer: FakeRecognizer()
        )
        let processed = try await queue.processOneClip()
        XCTAssertFalse(processed)
    }
}
