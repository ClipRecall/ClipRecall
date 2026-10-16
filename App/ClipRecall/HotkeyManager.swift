import Carbon
import AppKit
import ClipRecallCore

/// 快捷键设置（可配置结构：T2.6 设置页将来直接读写）。
/// 默认：Option + ` （反引号）。
struct HotkeySettings: Equatable, Sendable {
    /// 键码（Carbon keycode，如反引号 = 50）
    var keyCode: UInt32
    /// 修饰键（Carbon 位掩码：cmd = 1<<8，shift = 1<<9，option = 1<<11，control = 1<<12）
    var modifiers: UInt32

    static let `default` = HotkeySettings(keyCode: 50, modifiers: 1 << 11)
}

/// 全局快捷键管理器：Carbon 热键注册（系统级，无需辅助功能权限）。
/// 事件在主线程派发到 @MainActor 回调。
final class HotkeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (@MainActor () -> Void)?

    private static let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4950), id: 1)  // "CLIP"

    /// 注册热键；重复注册前会先注销旧热键。
    func register(_ settings: HotkeySettings, action: @escaping @MainActor () -> Void) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotkeyEventHandler,
            1,
            &eventType,
            userData,
            &handlerRef
        )

        let hotKeyID = Self.hotKeyID
        let status = RegisterEventHotKey(
            settings.keyCode,
            settings.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            Log.error("全局快捷键注册失败：\(status)", module: .app)
            unregister()
        } else {
            Log.info("全局快捷键已注册：Option+`", module: .app)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        action = nil
    }

    /// C 函数指针风格的事件处理器：通过 userData 找回管理器实例，主线程派发动作。
    private static let hotkeyEventHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                manager.action?()
            }
        }
        return noErr
    }
}
