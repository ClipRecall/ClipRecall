import Foundation

/// 代码语言检测：按特征词汇打分（启发式）。
/// 支持 Swift / Python / JavaScript；得分 ≥2 且最高者（无并列）胜出。
/// 已知取舍：阈值较低，极少数普通句子可能误判；正式版可换更强的模型。
public enum CodeLanguageDetection {
    /// 检测文本是否为代码并返回语言名；非代码或无法确定返回 nil。
    public static func detect(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let scores = [
            ("Swift", score(of: text, signals: swiftSignals)),
            ("Python", score(of: text, signals: pythonSignals)),
            ("JavaScript", score(of: text, signals: javaScriptSignals)),
        ]
        guard let winner = scores.max(by: { $0.1 < $1.1 }) else { return nil }
        guard winner.1 >= 2 else { return nil }
        let tied = scores.filter { $0.1 == winner.1 }
        guard tied.count == 1 else { return nil }   // 分数并列不武断
        return winner.0
    }

    static func score(of text: String, signals: [String]) -> Int {
        signals.reduce(0) { $0 + text.occurrenceCount(of: $1) }
    }

    static let swiftSignals = [
        "import SwiftUI", "import Foundation", "import UIKit", "import AppKit",
        "func ", "struct ", "@main", "guard let", "if let", "-> ",
        "some View",
    ]

    static let pythonSignals = [
        "def ", "import os", "import sys", "from ", "print(", "elif ",
        "if __name__", "self.", "lambda ", "None",
    ]

    static let javaScriptSignals = [
        "const ", "let ", "function ", "=>", "console.log", "document.",
        "export ", "import {", "undefined", "typeof ",
    ]
}

private extension String {
    /// 非重叠出现次数。
    func occurrenceCount(of substring: String) -> Int {
        var count = 0
        var searchRange = startIndex..<endIndex
        while let range = range(of: substring, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<endIndex
        }
        return count
    }
}
