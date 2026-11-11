import Foundation

public enum BorderMarkError: LocalizedError, Equatable {
    case unreadableImage(URL)
    case renderFailed(String)
    case exportFailed(URL)
    case invalidTemplate(file: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableImage(let url):
            return "无法读取图片：\(url.lastPathComponent)"
        case .renderFailed(let reason):
            return "渲染失败：\(reason)"
        case .exportFailed(let url):
            return "导出失败：\(url.lastPathComponent)"
        case .invalidTemplate(let file, let reason):
            return "模板 \(file) 无效：\(reason)"
        }
    }
}
