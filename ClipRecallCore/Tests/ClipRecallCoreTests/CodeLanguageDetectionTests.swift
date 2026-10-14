import XCTest
@testable import ClipRecallCore

final class CodeLanguageDetectionTests: XCTestCase {
    func testSwiftSnippet() {
        let code = """
        func greet() -> String {
            let name = "world"
            return name
        }
        """
        XCTAssertEqual(CodeLanguageDetection.detect(in: code), "Swift")
    }

    func testPythonSnippet() {
        let code = """
        def greet():
            print("hello")
        """
        XCTAssertEqual(CodeLanguageDetection.detect(in: code), "Python")
    }

    func testJavaScriptSnippet() {
        let code = """
        const greet = () => {
            console.log("hello");
        };
        """
        XCTAssertEqual(CodeLanguageDetection.detect(in: code), "JavaScript")
    }

    func testPlainSentenceNotCode() {
        XCTAssertNil(CodeLanguageDetection.detect(in: "今天天气不错，去公园散步。"))
    }

    func testSingleSignalNotEnough() {
        XCTAssertNil(CodeLanguageDetection.detect(in: "一个 func 都没有的句子"))
    }

    func testTieNotConclusive() {
        // Swift "func "+"struct " 与 Python "def "+"print(" 各 2 分 → 不武断
        XCTAssertNil(CodeLanguageDetection.detect(in: "func struct def print("))
    }

    func testEmptyText() {
        XCTAssertNil(CodeLanguageDetection.detect(in: ""))
    }
}
