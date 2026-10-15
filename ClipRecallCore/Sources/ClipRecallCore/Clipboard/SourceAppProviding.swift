import Foundation

/// 前台应用信息。
public struct FrontmostAppInfo: Equatable, Sendable {
    public let bundleId: String
    public let name: String?

    public init(bundleId: String, name: String?) {
        self.bundleId = bundleId
        self.name = name
    }
}

/// 前台应用检测抽象：核心库零平台依赖，App 层注入 NSWorkspace 实现，测试注入假实现。
public protocol SourceAppProviding: Sendable {
    func frontmostApp() -> FrontmostAppInfo?
}

/// 排除 App 名单：名单内 App 复制的内容不进入历史。
/// 默认名单预置常见密码管理器；UI 编辑在设置页（T2.6.2）接入。
public final class AppExclusionList: @unchecked Sendable {
    private let lock = NSLock()
    private var bundleIds: Set<String>

    /// - Parameter defaults: 初始名单；默认预置常见密码管理器。
    public init(defaults: Set<String> = AppExclusionList.defaultBundleIds) {
        self.bundleIds = defaults
    }

    public func contains(_ bundleId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return bundleIds.contains(bundleId)
    }

    public func add(_ bundleId: String) {
        lock.lock()
        bundleIds.insert(bundleId)
        lock.unlock()
    }

    public func remove(_ bundleId: String) {
        lock.lock()
        bundleIds.remove(bundleId)
        lock.unlock()
    }

    public var all: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return bundleIds
    }

    /// 默认名单：常见密码管理器。
    public static let defaultBundleIds: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword8",
        "com.1password.1password",
        "org.keepassx.keepassxc",
        "net.keepassxc.keepassxc",
        "com.bitwarden.desktop",
    ]
}
