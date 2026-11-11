import CoreGraphics
import Foundation

/// 一张可用的品牌 Logo 图片。文件名（不含扩展名）就是品牌名，如 `Nikon.png`。
public struct LogoEntry: Identifiable, Equatable, Hashable, Sendable {
    /// 归一化后的品牌键：小写、只保留字母数字
    public let id: String
    public let name: String
    public let url: URL

    public init(url: URL) {
        let stem = url.deletingPathExtension().lastPathComponent
        self.id = LogoLibrary.normalized(stem)
        self.name = stem
        self.url = url
    }
}

/// Logo 图片库：应用自带的一组 + 用户文件夹里的。用户文件夹里的同名文件优先。
public enum LogoLibrary {
    public static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp"]
    private static let folderName = "Logos"
    private static let resourceBundleName = "BorderMark_BorderMarkCore.bundle"

    public static var userDirectory: URL {
        TemplateStore.userDirectory.deletingLastPathComponent().appendingPathComponent(folderName, isDirectory: true)
    }

    /// 应用自带 Logo 可能在的位置。不用 `Bundle.module`：它在手工打的 .app 里找不到资源时会直接崩溃。
    public static var bundledDirectories: [URL] {
        let main = Bundle.main
        let executableDirectory = main.executableURL?.deletingLastPathComponent()
        let candidates: [URL?] = [
            main.resourceURL?.appendingPathComponent(folderName),
            executableDirectory?.appendingPathComponent(folderName),
            executableDirectory?.appendingPathComponent(resourceBundleName).appendingPathComponent(folderName),
            executableDirectory?.appendingPathComponent(resourceBundleName)
                .appendingPathComponent("Contents/Resources").appendingPathComponent(folderName),
        ]
        return candidates.compactMap { $0 }
    }

    /// 扫描目录得到 Logo 列表。靠后的目录覆盖靠前目录里的同名品牌，结果按名称排序。
    public static func entries(in directories: [URL]) -> [LogoEntry] {
        let byID = directories.reduce(into: [String: LogoEntry]()) { result, directory in
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in files where supportedExtensions.contains(file.pathExtension.lowercased()) {
                let entry = LogoEntry(url: file)
                guard !entry.id.isEmpty else { continue }
                result[entry.id] = entry
            }
        }
        return byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func allEntries() -> [LogoEntry] {
        entries(in: bundledDirectories + [userDirectory])
    }

    /// 按 EXIF 的厂商字段找 Logo：厂商名以哪个品牌键开头就用哪个，多个命中取最长的。
    /// 例如 "NIKON CORPORATION" 命中 `Nikon`，"OM Digital Solutions" 命中 `OM Digital` 而不是 `OM`。
    public static func match(make: String?, in entries: [LogoEntry]) -> LogoEntry? {
        guard let make else { return nil }
        let key = normalized(make)
        guard !key.isEmpty else { return nil }
        return entries
            .filter { key.hasPrefix($0.id) }
            .max { $0.id.count < $1.id.count }
    }

    static func normalized(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }
}

/// Logo 着色：把带透明通道的单色 Logo 染成指定颜色，这样同一张图在白底和黑底模板上都能用。
enum LogoTint {
    /// 没有透明通道的图（如 JPEG）染色后会变成一个实心方块，所以原样返回。
    static func tinted(_ logo: CGImage, with color: CGColor) -> CGImage {
        guard hasAlpha(logo),
              let context = CGContext(
                  data: nil, width: logo.width, height: logo.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return logo }

        let bounds = CGRect(x: 0, y: 0, width: logo.width, height: logo.height)
        context.draw(logo, in: bounds)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color)
        context.fill(bounds)
        return context.makeImage() ?? logo
    }

    static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }
}
