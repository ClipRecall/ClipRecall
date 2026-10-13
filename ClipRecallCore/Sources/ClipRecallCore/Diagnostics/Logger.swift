import os

/// 日志模块标识：控制台（Console.app）中按类别过滤。
public enum LogModule: String, CaseIterable, Sendable {
    case app
    case models
    case clipboard
    case storage
    case search
    case ai
    case sync
    case diagnostics
}

/// 统一日志封装：分级别 + 分模块，基于系统 os.Logger。
/// 使用示例：`Log.info("剪贴板捕获成功", module: .clipboard)`
public enum Log {
    /// 子系统标识：控制台中按此过滤本 App 日志
    public static let subsystem = "com.andromeda.ClipRecall"

    public static func debug(
        _ message: String,
        module: LogModule = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        logger(module).debug("[\(file):\(line)] \(message, privacy: .public)")
    }

    public static func info(
        _ message: String,
        module: LogModule = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        logger(module).info("[\(file):\(line)] \(message, privacy: .public)")
    }

    public static func warning(
        _ message: String,
        module: LogModule = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        logger(module).notice("[\(file):\(line)] \(message, privacy: .public)")
    }

    public static func error(
        _ message: String,
        module: LogModule = .app,
        file: String = #fileID,
        line: Int = #line
    ) {
        logger(module).error("[\(file):\(line)] \(message, privacy: .public)")
    }

    private static func logger(_ module: LogModule) -> os.Logger {
        os.Logger(subsystem: subsystem, category: module.rawValue)
    }
}
