/// 剪贴板读取抽象：核心库不依赖平台剪贴板实现。
/// 变化检测依据：内容每次变化，changeCount 递增。
/// App 层注入系统剪贴板适配器；测试注入可控的假实现。
public protocol PasteboardReading: Sendable {
    var changeCount: Int { get }
}
