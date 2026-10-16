import XCTest
import GRDB
@testable import ClipRecallCore

/// T3.2.1：过滤器模型与组合查询。
final class ClipFilterTests: XCTestCase {
    private var tempDirectory: URL!
    private var repository: ClipRepository!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(
            "ClipRecallCoreTests-\(UUID().uuidString)", isDirectory: true
        )
        let manager = DatabaseManager(directoryURL: tempDirectory)
        repository = ClipRepository(databaseManager: manager)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeClip(
        text: String? = nil,
        type: ClipType = .text,
        sourceBundleId: String? = nil,
        capturedAt: Date = Date()
    ) -> Clip {
        Clip(
            capturedAt: capturedAt,
            sourceApp: sourceBundleId.map { SourceApp(bundleId: $0, name: $0) },
            primaryType: type,
            formats: [
                Format(
                    type: text != nil ? FormatUTI.plainText : FormatUTI.png,
                    payload: .inline(Data((text ?? "").utf8))
                )
            ],
            textPreview: text
        )
    }

    func testFilterByType() throws {
        try repository.save(makeClip(text: "文本条目"))
        try repository.save(makeClip(text: "图片条目", type: .image))
        try repository.save(makeClip(text: "https://example.com", type: .url))
        let hits = try repository.fetchClips(query: "", filter: ClipFilter(types: [.text]))
        XCTAssertEqual(hits.map(\.textPreview), ["文本条目"])
    }

    func testFilterBySourceApp() throws {
        try repository.save(makeClip(text: "来自 Safari", sourceBundleId: "com.apple.Safari"))
        try repository.save(makeClip(text: "来自 VS Code", sourceBundleId: "com.microsoft.VSCode"))
        let hits = try repository.fetchClips(
            query: "", filter: ClipFilter(sourceAppBundleId: "com.apple.Safari")
        )
        XCTAssertEqual(hits.map(\.textPreview), ["来自 Safari"])
    }

    func testFilterByTimeExcludesOld() throws {
        let base = Date()
        let old = Calendar.current.date(byAdding: .day, value: -40, to: base) ?? base
        try repository.save(makeClip(text: "旧条目", capturedAt: old))
        try repository.save(makeClip(text: "新条目", capturedAt: base))
        let hits = try repository.fetchClips(
            query: "", filter: ClipFilter(timeRange: .last30Days)
        )
        XCTAssertEqual(hits.map(\.textPreview), ["新条目"])
    }

    func testFilterByTimeToday() throws {
        let base = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: base) ?? base
        try repository.save(makeClip(text: "昨天的", capturedAt: yesterday))
        try repository.save(makeClip(text: "今天的", capturedAt: base))
        let hits = try repository.fetchClips(
            query: "", filter: ClipFilter(timeRange: .today)
        )
        XCTAssertEqual(hits.map(\.textPreview), ["今天的"])
    }

    func testCombinedFilters() throws {
        let base = Date()
        try repository.save(
            makeClip(text: "Safari 文本 新", sourceBundleId: "com.apple.Safari", capturedAt: base)
        )
        try repository.save(
            makeClip(text: "Safari 文本 旧", sourceBundleId: "com.apple.Safari",
                     capturedAt: Calendar.current.date(byAdding: .day, value: -40, to: base) ?? base)
        )
        try repository.save(
            makeClip(text: "Chrome 文本", sourceBundleId: "com.google.Chrome", capturedAt: base)
        )
        try repository.save(
            makeClip(text: "Safari 链接", type: .url, sourceBundleId: "com.apple.Safari", capturedAt: base)
        )
        // 类型 + 来源 + 时间 三条件组合：只剩"Safari 文本 新"
        let hits = try repository.fetchClips(
            query: "",
            filter: ClipFilter(
                types: [.text],
                sourceAppBundleId: "com.apple.Safari",
                timeRange: .last30Days
            )
        )
        XCTAssertEqual(hits.map(\.textPreview), ["Safari 文本 新"])
    }

    func testQueryCombinedWithFilter() throws {
        try repository.save(makeClip(text: "alpha 文本", sourceBundleId: "com.apple.Safari"))
        try repository.save(makeClip(text: "alpha 链接", type: .url, sourceBundleId: "com.apple.Safari"))
        try repository.save(makeClip(text: "alpha 图片", type: .image, sourceBundleId: "com.apple.Safari"))
        // 关键词 + 类型过滤：alpha 命中的 3 条里只取 URL 类型
        let hits = try repository.fetchClips(
            query: "alpha", filter: ClipFilter(types: [.url])
        )
        XCTAssertEqual(hits.map(\.textPreview), ["alpha 链接"])
    }

    func testEmptyFilterReturnsAll() throws {
        try repository.save(makeClip(text: "第一条"))
        try repository.save(makeClip(text: "第二条"))
        let hits = try repository.fetchClips(query: "")
        let recent = try repository.fetchRecent(limit: 100)
        XCTAssertEqual(hits.map(\.id), recent.map(\.id))
    }

    func testNoResultsReturnsEmpty() throws {
        try repository.save(makeClip(text: "唯一的条目"))
        let hits = try repository.fetchClips(
            query: "", filter: ClipFilter(sourceAppBundleId: "com.nonexistent.App")
        )
        XCTAssertTrue(hits.isEmpty)
    }

    func testLimitRespected() throws {
        try repository.save(makeClip(text: "条目1"))
        try repository.save(makeClip(text: "条目2"))
        try repository.save(makeClip(text: "条目3"))
        let hits = try repository.fetchClips(query: "", limit: 2)
        XCTAssertEqual(hits.count, 2)
    }
}
