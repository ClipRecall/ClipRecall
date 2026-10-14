import XCTest
@testable import ClipRecallCore

final class ClipCapturePipelineTests: XCTestCase {
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

    private func makePipeline(pasteboard: PasteboardReading, store: RecentClipsStore) -> ClipCapturePipeline {
        ClipCapturePipeline(pasteboard: pasteboard, store: store, blobManager: blobManager)
    }

    func testTextChangeProducesClip() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("你好世界", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].primaryType, .text)
        XCTAssertEqual(store.clips[0].textPreview, "你好世界")
    }

    func testRichTextChangeProducesRichTextClip() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("带格式", forType: FormatUTI.plainText)
        pasteboard.setData(Data("<b>带格式</b>".utf8), forType: FormatUTI.html)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].primaryType, .richText)
        XCTAssertEqual(store.clips[0].formats.count, 2)
    }

    func testEmptyPasteboardProducesNoClip() {
        let pasteboard = FakeTextPasteboard()
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)

        XCTAssertTrue(store.clips.isEmpty)
    }

    func testImageChangeProducesImageClip() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D])
            + Data("IHDR".utf8) + Data(repeating: 0, count: 8), forType: FormatUTI.png)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].primaryType, .image)
    }

    func testWritePayloadsConvertInlineAndFileBacked() throws {
        let inline = Format(type: FormatUTI.plainText, payload: .inline(Data("内联".utf8)))
        let bigData = Data(repeating: 0x55, count: 70 * 1024)
        let fileBackedPath = try blobManager.write(bigData, fileExtension: "png")
        let fileBacked = Format(type: FormatUTI.png, payload: .file(path: fileBackedPath))

        let items = PasteboardWritePayloads.items(from: [inline, fileBacked], blobManager: blobManager)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].type, FormatUTI.plainText)
        XCTAssertEqual(String(data: items[0].data, encoding: .utf8), "内联")
        XCTAssertEqual(items[1].type, FormatUTI.png)
        XCTAssertEqual(items[1].data, bigData)
    }

    func testWritePayloadsOmitMissingBlob() {
        let missing = Format(type: FormatUTI.png, payload: .file(path: "不存在的.png"))
        let items = PasteboardWritePayloads.items(from: [missing], blobManager: blobManager)
        XCTAssertTrue(items.isEmpty)
    }

    func testSuppressionWindowSkipsChanges() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("回声测试", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.suppressChanges(for: 0.3)
        pipeline.clipboardDidChange(changeCount: 5)   // 静默窗内 → 跳过
        pipeline.clipboardDidChange(changeCount: 6)   // 静默窗内（多次变化都拦） → 跳过
        XCTAssertTrue(store.clips.isEmpty)

        Thread.sleep(forTimeInterval: 0.35)
        pipeline.clipboardDidChange(changeCount: 7)   // 窗口过期 → 正常捕获
        XCTAssertEqual(store.clips.count, 1)
    }

    func testBaselineContentIsNeverRecorded() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("旧内容", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)
        pipeline.setBaselineFingerprint(
            FormatFingerprint.contentIdentity(from: ClipContentCapture.capture(from: pasteboard))
        )

        // 系统抖动：版本号变了但内容还是旧的 → 跳过
        pipeline.clipboardDidChange(changeCount: 5)
        XCTAssertTrue(store.clips.isEmpty)

        // 真正的新复制 → 记录
        pasteboard.setString("新内容", forType: FormatUTI.plainText)
        pipeline.clipboardDidChange(changeCount: 6)
        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].textPreview, "新内容")
    }

    func testBaselineContentRecordableAfterOtherCopies() {
        // 回归："monitor" 案例——基线内容在其它复制发生后应可正常记录（一次性基线）
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("monitor", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)
        pipeline.setBaselineFingerprint(
            FormatFingerprint.contentIdentity(from: ClipContentCapture.capture(from: pasteboard))
        )

        pipeline.clipboardDidChange(changeCount: 5)   // 启动抖动（基线内容）→ 跳过
        XCTAssertTrue(store.clips.isEmpty)

        pasteboard.setString("A", forType: FormatUTI.plainText)
        pipeline.clipboardDidChange(changeCount: 6)   // 其它内容 → 记录，基线失效
        XCTAssertEqual(store.clips.count, 1)

        pasteboard.setString("monitor", forType: FormatUTI.plainText)
        pipeline.clipboardDidChange(changeCount: 7)   // 再复制基线内容 → 应正常记录
        XCTAssertEqual(store.clips.count, 2)
        XCTAssertEqual(store.clips[0].textPreview, "monitor")
    }

    func testIdenticalConsecutiveContentIsDeduplicated() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("同样内容", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)
        pipeline.clipboardDidChange(changeCount: 2)   // 内容相同 → 去重
        XCTAssertEqual(store.clips.count, 1)

        pasteboard.setString("不同内容", forType: FormatUTI.plainText)
        pipeline.clipboardDidChange(changeCount: 3)   // 内容不同 → 记录
        XCTAssertEqual(store.clips.count, 2)
    }

    func testFingerprintStability() {
        let a1 = [Format(type: FormatUTI.plainText, payload: .inline(Data("相同".utf8)))]
        let a2 = [Format(type: FormatUTI.plainText, payload: .inline(Data("相同".utf8)))]
        let b = [Format(type: FormatUTI.plainText, payload: .inline(Data("不同".utf8)))]
        XCTAssertEqual(FormatFingerprint.make(from: a1), FormatFingerprint.make(from: a2))
        XCTAssertNotEqual(FormatFingerprint.make(from: a1), FormatFingerprint.make(from: b))
    }

    func testCodeChangeAttachesLanguageMetadata() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setString("def greet():\n    print(\"hello\")", forType: FormatUTI.plainText)
        let store = RecentClipsStore(limit: 10)
        let pipeline = makePipeline(pasteboard: pasteboard, store: store)

        pipeline.clipboardDidChange(changeCount: 1)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].primaryType, .code)
        let plain = store.clips[0].formats.first(where: { $0.type == FormatUTI.plainText })
        XCTAssertEqual(plain?.metadata.codeLanguage, "Python")
    }
}
