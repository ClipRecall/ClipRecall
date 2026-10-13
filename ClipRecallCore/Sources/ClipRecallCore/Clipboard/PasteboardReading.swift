import Foundation

/// 剪贴板读取抽象：核心库不依赖平台剪贴板实现。
/// 变化检测依据：内容每次变化，changeCount 递增。
/// App 层注入系统剪贴板适配器；测试注入可控的假实现。
///
/// 注意：types / data / string 必须是正式协议要求（而非仅有扩展默认实现），
/// 否则通过协议类型调用时不会动态分发到实现类。
public protocol PasteboardReading: Sendable {
    var changeCount: Int { get }
    /// 剪贴板上存在的类型（UTI）清单。
    var types: [String] { get }
    /// 读取指定类型的数据；不存在返回 nil。
    func data(forType type: String) -> Data?
    /// 读取指定类型的字符串；不存在返回 nil。
    func string(forType type: String) -> String?
}

public extension PasteboardReading {
    var types: [String] { [] }
    func data(forType type: String) -> Data? { nil }
    func string(forType type: String) -> String? { nil }
}
