import Foundation
import Vision

// MARK: - 图片 OCR（T3.3.1）

/// 识别器协议：真实现 + 测试假实现（T3.3.2 队列注入用）。
public protocol ImageTextRecognizing: Sendable {
    /// 识别图片中的文字；识别不出返回空字符串；坏图片 / 不支持格式抛错。
    func recognizeText(in imageData: Data) throws -> String
}

/// 图片文字识别：Vision 框架薄封装（纯本地识别，不上传）。
///
/// 识别配置：`.accurate` 质量优先；中英混排（zh-Hans 主、en-US 副）；关闭语言纠正——
/// 保留识别原字符，避免纠正改写搜索词。
///
/// 注意：本接口为**同步阻塞**（Vision 本身同步执行、CPU 密集）——后台调度由
/// T3.3.2 增量索引队列负责，不要在 MainActor 上直接调用。
public struct ImageTextRecognizer: ImageTextRecognizing, Sendable {
    public init() {}

    /// 识别图片中的文字；识别不出返回空字符串；坏图片 / 不支持格式抛错。
    public func recognizeText(in imageData: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(data: imageData)
        try handler.perform([request])

        guard let observations = request.results else { return "" }
        let lines = observations.compactMap { observation -> String? in
            observation.topCandidates(1).first?.string
        }
        let text = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
}
