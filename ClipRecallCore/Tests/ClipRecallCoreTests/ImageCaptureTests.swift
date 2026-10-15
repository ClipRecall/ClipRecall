import XCTest
@testable import ClipRecallCore

final class ImageCaptureTests: XCTestCase {
    // MARK: - 字节级样本构造

    private func makePNG(width: UInt32, height: UInt32) -> Data {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += [0x00, 0x00, 0x00, 0x0D]  // IHDR 长度 13
        bytes += Array("IHDR".utf8)
        bytes += beBytes(width)
        bytes += beBytes(height)
        return Data(bytes)
    }

    private func beBytes(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private func makeTIFF(littleEndian: Bool, short: Bool, width: UInt32, height: UInt32) -> Data {
        var bytes: [UInt8] = littleEndian ? [0x49, 0x49] : [0x4D, 0x4D]
        func u16(_ value: UInt16) -> [UInt8] {
            littleEndian ? [UInt8(value & 0xFF), UInt8(value >> 8)] : [UInt8(value >> 8), UInt8(value & 0xFF)]
        }
        func u32(_ value: UInt32) -> [UInt8] {
            littleEndian
                ? [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 24 & 0xFF)]
                : [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
        }
        bytes += u16(42)   // 魔数
        bytes += u32(8)    // IFD 偏移
        bytes += u16(2)    // 条目数
        for (tag, value) in [(UInt16(256), width), (UInt16(257), height)] {
            bytes += u16(tag)
            bytes += u16(short ? 3 : 4)
            bytes += u32(1)  // count = 1
            if short {
                bytes += u16(UInt16(value))
                bytes += [0x00, 0x00]  // 填充
            } else {
                bytes += u32(value)
            }
        }
        return Data(bytes)
    }

    // MARK: - PNG 解析

    func testPNGSize() {
        let data = makePNG(width: 640, height: 480)
        XCTAssertEqual(ImageCapture.size(from: data, type: FormatUTI.png), PixelSize(width: 640, height: 480))
    }

    func testPNGRejectsBadSignature() {
        var data = makePNG(width: 1, height: 1)
        data[0] = 0x00
        XCTAssertNil(ImageCapture.size(from: data, type: FormatUTI.png))
    }

    func testPNGRejectsShortData() {
        XCTAssertNil(ImageCapture.size(from: Data([0x89, 0x50]), type: FormatUTI.png))
    }

    // MARK: - TIFF 解析

    func testTIFFLittleEndianLong() {
        let data = makeTIFF(littleEndian: true, short: false, width: 1920, height: 1080)
        XCTAssertEqual(ImageCapture.size(from: data, type: FormatUTI.tiff), PixelSize(width: 1920, height: 1080))
    }

    func testTIFFBigEndianLong() {
        let data = makeTIFF(littleEndian: false, short: false, width: 800, height: 600)
        XCTAssertEqual(ImageCapture.size(from: data, type: FormatUTI.tiff), PixelSize(width: 800, height: 600))
    }

    func testTIFFShortEntries() {
        let data = makeTIFF(littleEndian: false, short: true, width: 640, height: 480)
        XCTAssertEqual(ImageCapture.size(from: data, type: FormatUTI.tiff), PixelSize(width: 640, height: 480))
    }

    func testTIFFRejectsBadMagic() {
        var data = makeTIFF(littleEndian: true, short: false, width: 1, height: 1)
        data[0] = 0x00
        data[1] = 0x00
        XCTAssertNil(ImageCapture.size(from: data, type: FormatUTI.tiff))
    }

    // MARK: - 采集

    func testCapturePNGOnly() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(makePNG(width: 320, height: 240), forType: FormatUTI.png)
        let formats = ImageCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.count, 1)
        XCTAssertEqual(formats[0].type, FormatUTI.png)
        XCTAssertEqual(formats[0].metadata.pixelSize, PixelSize(width: 320, height: 240))
    }

    func testCapturePNGAndTIFF() {
        let pasteboard = FakeTextPasteboard()
        pasteboard.setData(makePNG(width: 10, height: 20), forType: FormatUTI.png)
        pasteboard.setData(
            makeTIFF(littleEndian: true, short: false, width: 30, height: 40),
            forType: FormatUTI.tiff
        )
        let formats = ImageCapture.capture(from: pasteboard)
        XCTAssertEqual(formats.map(\.type), [FormatUTI.png, FormatUTI.tiff])
    }
}
