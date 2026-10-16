import Foundation
import ClipRecallCore

/// 应用设置的统一读写与默认值（T2.6.2，底层为 SettingsStore 键值存储）。
@MainActor
final class SettingsApplication {
    private let store = SettingsStore()

    private enum Key {
        static let retentionMaxCount = "retention.maxCount"
        static let retentionMaxDays = "retention.maxDays"
        static let maskingEnabled = "masking.enabled"
        static let maskingRatio = "masking.ratio"
        static let maskPosition = "masking.position"
        static let directPaste = "paste.direct"
        static let plainText = "paste.plainText"
        static let hotkeyKeyCode = "hotkey.keyCode"
        static let hotkeyModifiers = "hotkey.modifiers"
        static let excludedApps = "exclusion.bundleIds"
    }

    // MARK: - 保留策略

    var retentionPolicy: RetentionPolicy {
        get {
            let count = store.string(forKey: Key.retentionMaxCount).flatMap(Int.init) ?? 2000
            let days = store.string(forKey: Key.retentionMaxDays).flatMap(Int.init) ?? 30
            return RetentionPolicy(maxCount: count, maxDays: days)
        }
        set {
            store.set(String(newValue.maxCount), forKey: Key.retentionMaxCount)
            store.set(String(newValue.maxDays), forKey: Key.retentionMaxDays)
        }
    }

    // MARK: - 敏感打码

    var maskingEnabled: Bool {
        get { store.string(forKey: Key.maskingEnabled) != "0" }
        set { store.set(newValue ? "1" : "0", forKey: Key.maskingEnabled) }
    }

    var maskingRatio: Double {
        get { store.string(forKey: Key.maskingRatio).flatMap(Double.init) ?? 0.5 }
        set { store.set(String(newValue), forKey: Key.maskingRatio) }
    }

    var maskPosition: MaskPosition {
        get { store.string(forKey: Key.maskPosition).flatMap(MaskPosition.init(rawValue:)) ?? .trailing }
        set { store.set(newValue.rawValue, forKey: Key.maskPosition) }
    }

    // MARK: - 粘贴

    var directPasteEnabled: Bool {
        get { store.string(forKey: Key.directPaste) == "1" }
        set { store.set(newValue ? "1" : "0", forKey: Key.directPaste) }
    }

    var plainTextPasteMode: Bool {
        get { store.string(forKey: Key.plainText) == "1" }
        set { store.set(newValue ? "1" : "0", forKey: Key.plainText) }
    }

    // MARK: - 快捷键

    var hotkeySettings: HotkeySettings {
        get {
            let code = store.string(forKey: Key.hotkeyKeyCode).flatMap(UInt32.init) ?? HotkeySettings.default.keyCode
            let mods = store.string(forKey: Key.hotkeyModifiers).flatMap(UInt32.init) ?? HotkeySettings.default.modifiers
            return HotkeySettings(keyCode: code, modifiers: mods)
        }
        set {
            store.set(String(newValue.keyCode), forKey: Key.hotkeyKeyCode)
            store.set(String(newValue.modifiers), forKey: Key.hotkeyModifiers)
        }
    }

    // MARK: - 排除名单

    var excludedBundleIds: Set<String> {
        get {
            guard let json = store.string(forKey: Key.excludedApps),
                  let decoded: [String] = Self.decodeJSON(json)
            else {
                return AppExclusionList.defaultBundleIds
            }
            return Set(decoded)
        }
        set {
            store.set(Self.encodeJSON(Array(newValue).sorted()), forKey: Key.excludedApps)
        }
    }

    // MARK: - JSON 辅助

    private static func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8)
        else { return "[]" }
        return string
    }

    private static func decodeJSON<T: Decodable>(_ string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
