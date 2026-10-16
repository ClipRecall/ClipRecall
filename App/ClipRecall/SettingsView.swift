import AppKit
import SwiftUI
import ClipRecallCore

/// 设置窗口：通用 / 隐私 / 粘贴 三组设置（T2.6.2）。
struct SettingsView: View {
    let appState: AppState

    @State private var recordingHotkey = false
    @State private var newBundleId = ""
    @State private var hotkeyMonitor: Any?
    @State private var retentionCountText = ""
    @State private var retentionDaysText = ""

    var body: some View {
        Form {
            Section("通用") {
                HStack {
                    Text("最大条数")
                    Spacer()
                    TextField("", text: $retentionCountText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitRetention() }
                }
                HStack {
                    Text("保留天数")
                    Spacer()
                    TextField("", text: $retentionDaysText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitRetention() }
                }
                hotkeyRecorder
            }
            Section("隐私") {
                Toggle("敏感内容打码", isOn: Binding(
                    get: { appState.maskingEnabled },
                    set: {
                        appState.setMasking(
                            enabled: $0, ratio: appState.maskingRatio, position: appState.maskPosition
                        )
                    }
                ))
                Slider(value: Binding(
                    get: { appState.maskingRatio },
                    set: {
                        appState.setMasking(
                            enabled: appState.maskingEnabled, ratio: $0, position: appState.maskPosition
                        )
                    }
                ), in: 0...1) {
                    Text("打码比例 \(Int(appState.maskingRatio * 100))%")
                }
                Picker("打码位置", selection: Binding(
                    get: { appState.maskPosition },
                    set: {
                        appState.setMasking(
                            enabled: appState.maskingEnabled, ratio: appState.maskingRatio, position: $0
                        )
                    }
                )) {
                    Text("前部").tag(MaskPosition.leading)
                    Text("中部").tag(MaskPosition.middle)
                    Text("后部").tag(MaskPosition.trailing)
                }
                exclusionEditor
            }
            Section("粘贴") {
                Toggle("直接粘贴（点击/回车自动粘贴到之前的 App）", isOn: Binding(
                    get: { appState.directPasteEnabled },
                    set: { appState.setDirectPaste($0) }
                ))
                Toggle("纯文本粘贴（剥离格式）", isOn: Binding(
                    get: { appState.plainTextPasteMode },
                    set: { appState.setPlainTextMode($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 460)
        .onAppear {
            retentionCountText = String(appState.retentionMaxCount)
            retentionDaysText = String(appState.retentionMaxDays)
        }
        .onDisappear {
            stopHotkeyRecording()
        }
    }

    /// 回车提交保留策略（非法输入回退为当前值）。
    private func commitRetention() {
        let count = Int(retentionCountText.trimmingCharacters(in: .whitespaces)) ?? appState.retentionMaxCount
        let days = Int(retentionDaysText.trimmingCharacters(in: .whitespaces)) ?? appState.retentionMaxDays
        appState.setRetention(maxCount: count, maxDays: days)
        retentionCountText = String(appState.retentionMaxCount)
        retentionDaysText = String(appState.retentionMaxDays)
    }

    // MARK: 快捷键录制器

    private var hotkeyRecorder: some View {
        HStack {
            Text("呼出快捷键：\(hotkeyLabel)")
                .font(.body)
            Spacer()
            Button(recordingHotkey ? "按下新组合键…" : "录制") {
                recordingHotkey ? stopHotkeyRecording() : startHotkeyRecording()
            }
        }
    }

    private var hotkeyLabel: String {
        let s = appState.settings.hotkeySettings
        var parts: [String] = []
        if s.modifiers & (1 << 11) != 0 { parts.append("⌥") }
        if s.modifiers & (1 << 8) != 0 { parts.append("⌘") }
        if s.modifiers & (1 << 9) != 0 { parts.append("⇧") }
        if s.modifiers & (1 << 12) != 0 { parts.append("⌃") }
        parts.append(keyName(for: s.keyCode))
        return parts.joined(separator: " ")
    }

    private func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 50: return "`"
        case 49: return "Space"
        case 36: return "↩"
        case 53: return "Esc"
        case 48: return "Tab"
        default: return String(format: "Key%u", keyCode)
        }
    }

    private func startHotkeyRecording() {
        recordingHotkey = true
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let carbonModifiers: UInt32 = {
                var mods: UInt32 = 0
                let flags = event.modifierFlags
                if flags.contains(.command) { mods |= 1 << 8 }
                if flags.contains(.shift) { mods |= 1 << 9 }
                if flags.contains(.option) { mods |= 1 << 11 }
                if flags.contains(.control) { mods |= 1 << 12 }
                return mods
            }()
            appState.updateHotkey(
                HotkeySettings(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
            )
            recordingHotkey = false
            return nil   // 吞掉这次按键
        }
    }

    private func stopHotkeyRecording() {
        recordingHotkey = false
        if let hotkeyMonitor {
            NSEvent.removeMonitor(hotkeyMonitor)
            self.hotkeyMonitor = nil
        }
    }

    // MARK: 排除名单编辑器

    private var exclusionEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("添加 App 的 bundle id（如 com.1password.1password）", text: $newBundleId)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, !appState.excludedBundleIds.contains(trimmed) {
                        appState.setExcludedBundleIds(appState.excludedBundleIds + [trimmed])
                    }
                    newBundleId = ""
                }
            ForEach(appState.excludedBundleIds, id: \.self) { bundleId in
                HStack {
                    Text(bundleId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("移除") {
                        appState.setExcludedBundleIds(
                            appState.excludedBundleIds.filter { $0 != bundleId }
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
    }
}
