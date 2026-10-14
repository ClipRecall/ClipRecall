import Foundation

/// 格式包内容指纹（FNV-1a 64 位），用于去重与回声抑制。
/// 零平台依赖：不引入加密哈希框架。
public enum FormatFingerprint {
    public static func make(from formats: [Format]) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for format in formats {
            hash = combine(hash, format.type)
            switch format.payload {
            case .inline(let data):
                hash = combine(hash, data)
            case .file(let path):
                hash = combine(hash, path)
            }
        }
        return String(hash, radix: 16)
    }

    /// 内容身份（用于去重 / 基线 / 回声抑制）：
    /// 文本条目只看纯文本内容——系统异步补格式会让同一内容的格式包形态不同，
    /// 按完整格式包比对会导致去重失灵；图片 / 文件等无纯文本的条目仍按完整内容。
    public static func contentIdentity(from formats: [Format]) -> String {
        if let plain = formats.first(where: { $0.type == FormatUTI.plainText }),
           case .inline(let data) = plain.payload {
            return "text:" + make(from: [Format(type: FormatUTI.plainText, payload: .inline(data))])
        }
        return "full:" + make(from: formats)
    }

    private static func combine(_ hash: UInt64, _ string: String) -> UInt64 {
        combine(hash, Data(string.utf8))
    }

    private static func combine(_ hash: UInt64, _ data: Data) -> UInt64 {
        var value = hash
        for byte in data {
            value = (value ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return value
    }
}
