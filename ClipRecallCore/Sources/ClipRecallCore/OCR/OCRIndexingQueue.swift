import Foundation

// MARK: - 增量 OCR 索引队列（T3.3.2）

/// 后台轮询队列：取待识别图片条目 → 识别 → 存结果，一次一张、串行处理。
///
/// 断点续传：完成与否由 `clips.ocrText` 表达（NULL = 待处理），重启后未处理的
/// 条目自动续上；新捕获的图片条目会被轮询自然接住。
///
/// 资源控制（TC3.3.2）：单线程串行 + 每张之间短暂停顿，批量索引不抢前台 CPU。
public final class OCRIndexingQueue: @unchecked Sendable {
    private let repository: ClipRepository
    private let recognizer: any ImageTextRecognizing
    private let idleInterval: Duration
    private let interClipPause: Duration
    private var loopTask: Task<Void, Never>?
    private let lock = NSLock()

    public init(
        repository: ClipRepository,
        recognizer: any ImageTextRecognizing = ImageTextRecognizer(),
        idleInterval: Duration = .seconds(3),
        interClipPause: Duration = .milliseconds(200)
    ) {
        self.repository = repository
        self.recognizer = recognizer
        self.idleInterval = idleInterval
        self.interClipPause = interClipPause
    }

    /// 启动后台循环（幂等：重复调用不叠加）。
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard loopTask == nil else { return }
        loopTask = Task.detached(priority: .background) { [weak self] in
            await self?.runLoop()
        }
    }

    /// 停止循环（App 退出前可选调用）。
    public func stop() {
        lock.lock()
        loopTask?.cancel()
        loopTask = nil
        lock.unlock()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            let processed: Bool
            do {
                processed = try await processOneClip()
            } catch {
                Log.error("OCR 循环异常：\(error)", module: .ocr)
                processed = false
            }
            let pause: Duration = processed ? interClipPause : idleInterval
            try? await Task.sleep(for: pause)
        }
    }

    /// 单步处理（测试入口）：取一条待处理图片并识别。返回是否处理了一条。
    @discardableResult
    public func processOneClip() async throws -> Bool {
        guard let clipId = try repository.nextOCRClipID() else { return false }
        do {
            if let data = try repository.imagePayloadData(clipId: clipId) {
                let text = try recognizer.recognizeText(in: data)
                try repository.setOCRText(clipId: clipId, text)
                Log.info("OCR 完成：\(clipId) → \(text.count) 字", module: .ocr)
            } else {
                // 无图片载荷（罕见）：标记完成，避免死循环
                try repository.setOCRText(clipId: clipId, "")
            }
        } catch {
            // 识别失败（坏图等）：标记完成，避免无限重试
            Log.error("OCR 失败（标记完成跳过）：\(clipId) \(error)", module: .ocr)
            try? repository.setOCRText(clipId: clipId, "")
        }
        return true
    }
}
