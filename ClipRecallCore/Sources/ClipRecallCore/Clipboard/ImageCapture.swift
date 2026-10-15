import Foundation

/// 图片采集器：读取剪贴板上的图片形态（PNG / TIFF），并从文件头解析像素尺寸。
/// 尺寸解析失败不影响采集（尺寸记为 nil，数据照常保存）。
public enum ImageCapture {
    /// 采集顺序：PNG 优先（系统剪贴板最常见形态）。
    public static let captureOrder: [String] = [FormatUTI.png, FormatUTI.tiff]

    /// 从剪贴板读取全部图片表示，返回格式包；没有图片形态时返回空数组。
    public static func capture(from pasteboard: PasteboardReading) -> [Format] {
        var formats: [Format] = []
        for type in captureOrder where pasteboard.types.contains(type) {
            guard let data = pasteboard.data(forType: type) else { continue }
            let pixelSize = size(from: data, type: type)
            let metadata = FormatMetadata(pixelSize: pixelSize)
            formats.append(Format(type: type, payload: .inline(data), metadata: metadata))
        }
        return formats
    }

    /// 按格式类型解析像素尺寸；非法或无法解析返回 nil。
    public static func size(from data: Data, type: String) -> PixelSize? {
        switch type {
        case FormatUTI.png: return pngSize(from: data)
        case FormatUTI.tiff: return tiffSize(from: data)
        default: return nil
        }
    }

    // MARK: - PNG

    /// PNG 尺寸位于文件头固定位置：
    /// 8 字节签名 + 4 字节长度 + "IHDR" + 4 字节宽 + 4 字节高（均为大端）。
    static func pngSize(from data: Data) -> PixelSize? {
        let bytes = [UInt8](data)
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count >= 24,
              Array(bytes[0..<8]) == signature,
              Array(bytes[12..<16]) == Array("IHDR".utf8)
        else { return nil }
        let width = beUInt32(Array(bytes[16..<20]))
        let height = beUInt32(Array(bytes[20..<24]))
        return PixelSize(width: Int(width), height: Int(height))
    }

    // MARK: - TIFF

    /// TIFF：字节序标记（II 小端 / MM 大端）+ 魔数 42 + IFD 条目表。
    /// 关注标签 256（宽）与 257（高）。
    static func tiffSize(from data: Data) -> PixelSize? {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return nil }
        let littleEndian: Bool
        if bytes[0] == 0x49, bytes[1] == 0x49 {
            littleEndian = true
        } else if bytes[0] == 0x4D, bytes[1] == 0x4D {
            littleEndian = false
        } else {
            return nil
        }
        guard readUInt16(bytes, at: 2, littleEndian: littleEndian) == 42 else { return nil }

        let ifdOffset = Int(readUInt32(bytes, at: 4, littleEndian: littleEndian))
        guard ifdOffset + 2 <= bytes.count else { return nil }
        let entryCount = Int(readUInt16(bytes, at: ifdOffset, littleEndian: littleEndian))

        var width: UInt32?
        var height: UInt32?
        for index in 0..<entryCount {
            let entry = ifdOffset + 2 + index * 12
            guard entry + 12 <= bytes.count else { return nil }
            let tag = readUInt16(bytes, at: entry, littleEndian: littleEndian)
            let type = readUInt16(bytes, at: entry + 2, littleEndian: littleEndian)
            let count = readUInt32(bytes, at: entry + 4, littleEndian: littleEndian)
            guard count == 1 else { continue }
            let raw: UInt32
            switch type {
            case 3:  // SHORT：值在前 2 字节
                raw = UInt32(readUInt16(bytes, at: entry + 8, littleEndian: littleEndian))
            case 4:  // LONG
                raw = readUInt32(bytes, at: entry + 8, littleEndian: littleEndian)
            default:
                continue
            }
            switch tag {
            case 256: width = raw
            case 257: height = raw
            default: break
            }
        }
        guard let width, let height else { return nil }
        return PixelSize(width: Int(width), height: Int(height))
    }

    // MARK: - 字节读取辅助

    static func beUInt32(_ bytes: [UInt8]) -> UInt32 {
        UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    static func readUInt16(_ bytes: [UInt8], at offset: Int, littleEndian: Bool) -> UInt16 {
        littleEndian
            ? UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
            : UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    static func readUInt32(_ bytes: [UInt8], at offset: Int, littleEndian: Bool) -> UInt32 {
        littleEndian
            ? UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            : UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }
}
