import Foundation
import NaturalLanguage

// MARK: - 文本向量化（T3.4.1）

/// 嵌入器协议：真实现 + 测试假实现（T3.4.2 向量检索注入用）。
public protocol TextEmbedding: Sendable {
    /// 文本 → L2 归一化句向量（归一化后点积 = 余弦相似度）；空文本 / 无有效词返回 nil。
    func embed(_ text: String) -> [Double]?
}

/// NLEmbedding 词向量平均实现：Apple 系统内置词向量词典（查表，不跑模型），
/// 纯本地、离线、毫秒级。质量粗略（词级相关性），满足剪贴板语义搜索场景
/// （架构决策见 docs/architecture.md——放弃本地 BERT 模型与云端 API）。
public struct TextEmbedder: TextEmbedding, Sendable {
    public init() {}

    public func embed(_ text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let language = Self.dominantLanguage(of: trimmed)
        guard let embedding = Self.embedding(for: language) else { return nil }

        var sum = [Double](repeating: 0, count: embedding.dimension)
        var count = 0
        for word in Self.tokens(in: trimmed, language: language) {
            guard let vector = embedding.vector(for: word) else { continue }
            for (index, value) in vector.enumerated() {
                sum[index] += Double(value)
            }
            count += 1
        }
        guard count > 0 else { return nil }
        let mean = sum.map { $0 / Double(count) }
        return Self.l2Normalize(mean)
    }

    // MARK: - 内部

    /// 主语言识别：中文族统一用简体词向量，其余回退英文。
    private static func dominantLanguage(of text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let language = recognizer.dominantLanguage,
           language == .simplifiedChinese || language == .traditionalChinese {
            return .simplifiedChinese
        }
        return .english
    }

    /// 语言对应词向量表（该语言表缺失时回退另一语言，保证永不失败）。
    private static func embedding(for language: NLLanguage) -> NLEmbedding? {
        if language == .simplifiedChinese {
            if let zh = NLEmbedding.wordEmbedding(for: .simplifiedChinese) { return zh }
            return NLEmbedding.wordEmbedding(for: .english)
        }
        if let en = NLEmbedding.wordEmbedding(for: .english) { return en }
        return NLEmbedding.wordEmbedding(for: .simplifiedChinese)
    }

    /// 分词（词单元，按识别语言；统一小写——NLEmbedding 查表对大小写敏感）。
    private static func tokens(in text: String, language: NLLanguage) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(language)
        tokenizer.string = text
        return tokenizer
            .tokens(for: text.startIndex..<text.endIndex)
            .map { String(text[$0]).lowercased() }
    }

    /// L2 归一化：归一化后向量点积即余弦相似度（T3.4.2 直接用点积检索）。
    private static func l2Normalize(_ vector: [Double]) -> [Double] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}
