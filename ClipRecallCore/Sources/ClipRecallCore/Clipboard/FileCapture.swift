import Foundation

/// 文件采集器：读取剪贴板上的文件引用（file-url），并记录每个文件的名称与大小档案。
/// 只存引用不存副本；文件已删除或目录时大小为 nil（档案仍保留）。
public enum FileCapture {
    /// 从剪贴板读取文件引用，返回格式包；无文件引用或内容非法时返回空数组。
    public static func capture(from pasteboard: PasteboardReading) -> [Format] {
        guard pasteboard.types.contains(FormatUTI.fileURL),
              let data = pasteboard.data(forType: FormatUTI.fileURL),
              let raw = String(data: data, encoding: .utf8)
        else { return [] }

        let references = parseReferences(from: raw)
        guard !references.isEmpty else { return [] }

        let metadata = FormatMetadata(fileCount: references.count, files: references)
        return [Format(type: FormatUTI.fileURL, payload: .inline(data), metadata: metadata)]
    }

    /// 解析 file-url 清单：每行一个 file:// 地址。
    static func parseReferences(from raw: String) -> [FileReference] {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("file://") }
            .compactMap { makeReference(from: $0) }
    }

    static func makeReference(from urlString: String) -> FileReference? {
        guard let url = URL(string: urlString) else { return nil }
        let name = url.lastPathComponent
        guard !name.isEmpty else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        // 目录本身也有"大小"（条目占用空间），但对用户无意义，按模型约定记 nil
        let isDirectory = attributes?[.type] as? FileAttributeType == .typeDirectory
        let size = isDirectory ? nil : attributes?[.size] as? Int64
        return FileReference(url: urlString, name: name, size: size)
    }
}
