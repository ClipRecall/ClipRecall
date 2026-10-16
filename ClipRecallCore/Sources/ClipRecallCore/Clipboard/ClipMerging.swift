import Foundation

/// 多选合并：按给定顺序拼接各条目的纯文本，换行分隔；跳过无纯文本的条目（图片/文件）。
public enum ClipMerging {
    /// 合并文本；所有条目都无纯文本时返回 nil。
    public static func mergedText(from clips: [Clip]) -> String? {
        let texts = clips.compactMap { ClipAppendPolicy.plainText(of: $0) }
        guard !texts.isEmpty else { return nil }
        return texts.joined(separator: "\n")
    }
}
