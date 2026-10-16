import XCTest
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import ClipRecallCore

/// T3.3.1：Vision OCR 封装。测试图片现场渲染生成（CoreText 绘字 → PNG），不依赖外部素材。
final class ImageTextRecognizerTests: XCTestCase {
    private let recognizer = ImageTextRecognizer()

    func testRecognizesEnglishText() throws {
        let data = try Self.renderPNG(text: "Hello OCR 123", fontName: "Helvetica")
        let result = try recognizer.recognizeText(in: data)
        XCTAssertTrue(
            result.lowercased().contains("hello"),
            "英文识别结果应包含 hello，实际：\(result)"
        )
    }

    func testRecognizesChineseText() throws {
        let data = try Self.renderPNG(text: "你好世界", fontName: "PingFang SC")
        let result = try recognizer.recognizeText(in: data)
        XCTAssertFalse(result.isEmpty, "中文识别结果不应为空")
    }

    func testBlankImageReturnsEmpty() throws {
        let data = try Self.renderPNG(text: "", fontName: "Helvetica")
        XCTAssertEqual(try recognizer.recognizeText(in: data), "")
    }

    func testCorruptDataThrows() throws {
        let garbage = Data([0x00, 0x01, 0x02, 0xFF])
        XCTAssertThrowsError(try recognizer.recognizeText(in: garbage))
    }

    // MARK: - 测试图片渲染

    /// 白底黑字渲染指定文本为 PNG 数据。
    private static func renderPNG(
        text: String, fontName: String, fontSize: CGFloat = 48,
        width: Int = 900, height: Int = 200
    ) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestError.renderFailed
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        if !text.isEmpty {
            let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ]
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: text, attributes: attributes)
            )
            context.textPosition = CGPoint(x: 20, y: CGFloat(height) - fontSize - 40)
            CTLineDraw(line, context)
        }

        guard let image = context.makeImage() else { throw TestError.renderFailed }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw TestError.renderFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw TestError.renderFailed }
        return output as Data
    }

    private enum TestError: Error {
        case renderFailed
    }
}
