/// 剪贴板内容的来源应用。
public struct SourceApp: Codable, Hashable, Sendable {
    /// 应用身份证号，如 com.apple.Safari
    public let bundleId: String
    /// 应用显示名，如 Safari
    public let name: String

    public init(bundleId: String, name: String) {
        self.bundleId = bundleId
        self.name = name
    }
}
