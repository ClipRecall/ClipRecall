import Foundation

/// 采集管道：变更事件 → 完整采集 → 落盘策略 → 组装 Clip → 存入缓存。
/// 实现 ClipboardChangeHandling，直接交给生命周期管家使用。
public final class ClipCapturePipeline: ClipboardChangeHandling, @unchecked Sendable {
    private let pasteboard: PasteboardReading
    private let store: RecentClipsStore
    private let blobManager: BlobFileManager
    private let lock = NSLock()
    private var suppressionUntil: Date?
    private var baselineFingerprint: String?

    public init(
        pasteboard: PasteboardReading,
        store: RecentClipsStore,
        blobManager: BlobFileManager
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.blobManager = blobManager
    }

    /// 抑制指定时长内的所有剪贴板变化（用于写回剪贴板后的"回声"抑制）。
    /// 期间用户真实的复制也会被忽略——调试阶段可接受，正式版改为内容比对式抑制。
    public func suppressChanges(for duration: TimeInterval) {
        lock.lock()
        suppressionUntil = Date().addingTimeInterval(duration)
        lock.unlock()
    }

    /// 注册启动基线指纹：监听开始前剪贴板上已有的内容永不作为新条目记录。
    public func setBaselineFingerprint(_ fingerprint: String) {
        lock.lock()
        baselineFingerprint = fingerprint
        lock.unlock()
    }

    public func clipboardDidChange(changeCount: Int) {
        lock.lock()
        if let until = suppressionUntil {
            if Date() < until {
                lock.unlock()
                return
            }
            suppressionUntil = nil
        }
        let baseline = baselineFingerprint
        lock.unlock()

        let formats = ClipContentCapture.capture(from: pasteboard)
        guard !formats.isEmpty else { return }
        var dispatched = PayloadWritePolicy.apply(to: formats, blobManager: blobManager)
        // 代码条目：把语言名写入首个纯文本格式的元数据
        if ClipTypeInference.primaryType(from: dispatched) == .code,
           let plainText = ClipTypeInference.plainTextContent(from: dispatched),
           let language = CodeLanguageDetection.detect(in: plainText),
           let plainIndex = dispatched.firstIndex(where: { $0.type == FormatUTI.plainText }) {
            dispatched[plainIndex].metadata.codeLanguage = language
        }
        let identity = FormatFingerprint.contentIdentity(from: dispatched)

        if let baseline {
            if identity == baseline {
                // 一次性基线：挡住启动抖动后即作废——之后复制相同内容应正常记录
                Log.info("跳过基线内容（监听前已在剪贴板）", module: .clipboard)
                baselineFingerprint = nil
                return
            }
            // 首个不同内容出现 → 基线使命结束
            baselineFingerprint = nil
        }

        let clip = Clip(
            primaryType: ClipTypeInference.primaryType(from: dispatched),
            formats: dispatched,
            textPreview: textPreview(from: dispatched)
        )
        store.append(clip)
        Log.info(
            "捕获新条目：\(clip.primaryType.rawValue)（\(dispatched.count) 个格式，changeCount=\(changeCount)）",
            module: .clipboard
        )
    }

    private func textPreview(from formats: [Format]) -> String? {
        guard let plain = formats.first(where: { $0.type == FormatUTI.plainText }),
              case .inline(let data) = plain.payload
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
