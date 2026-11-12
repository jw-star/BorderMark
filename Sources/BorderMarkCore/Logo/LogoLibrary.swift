import CoreGraphics
import Foundation

/// 一张可用的品牌 Logo 图片。
///
/// 文件名约定：`品牌.png` 是该品牌的默认 Logo，`品牌-变体名.png` 是它的其他样式，
/// 例如 `Nikon.png`、`Nikon-黄标.png`、`Leica-红标.png`。
public struct LogoEntry: Identifiable, Equatable, Hashable, Sendable {
    /// 唯一键：默认 Logo 为品牌键，变体为 `品牌键-变体键`
    public let id: String
    /// 文件名（不含扩展名）
    public let name: String
    /// 归一化后的品牌键：小写、只保留字母数字，用于和 EXIF 厂商字段匹配
    public let brandID: String
    /// 界面上显示的品牌名
    public let brandName: String
    /// 变体名；`nil` 表示品牌的默认 Logo
    public let variant: String?
    public let url: URL

    public init(url: URL) {
        let stem = url.deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: LogoLibrary.variantSeparator, maxSplits: 1)
        let brand = parts.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let variant = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        let brandID = LogoLibrary.normalized(brand)
        let variantID = LogoLibrary.normalized(variant)

        self.name = stem
        self.brandID = brandID
        self.brandName = brand
        self.variant = variantID.isEmpty ? nil : variant
        self.id = variantID.isEmpty ? brandID : "\(brandID)-\(variantID)"
        self.url = url
    }

    /// 界面上显示的样式名
    public var variantName: String { variant ?? "默认" }

    /// 彩色样式（样式名含“彩色”或 color）。彩色 Logo 只在“原色”模式下使用，染色后会失去意义。
    public var isColor: Bool {
        guard let variant = variant?.lowercased() else { return false }
        return LogoLibrary.colorVariantKeywords.contains { variant.contains($0) }
    }
}

/// 一个品牌及它的所有 Logo 样式。默认样式排在最前。
public struct LogoBrand: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let variants: [LogoEntry]

    /// 有默认 Logo 用默认，否则用第一个样式。
    public var defaultEntry: LogoEntry { variants[0] }

    /// 某种颜色模式下可选的样式。染色模式不提供彩色样式（除非这个品牌只有彩色的）。
    public func variants(isOriginalColor: Bool) -> [LogoEntry] {
        guard !isOriginalColor else { return variants }
        let monochrome = variants.filter { !$0.isColor }
        return monochrome.isEmpty ? variants : monochrome
    }

    /// 实际使用的样式：偏好有效就用偏好；否则原色模式优先彩色样式，染色模式用默认样式。
    public func entry(preferring id: String?, isOriginalColor: Bool = false) -> LogoEntry {
        let candidates = variants(isOriginalColor: isOriginalColor)
        if let preferred = candidates.first(where: { $0.id == id }) { return preferred }
        if isOriginalColor, let color = candidates.first(where: \.isColor) { return color }
        return candidates[0]
    }
}

/// Logo 图片库：应用自带的一组 + 用户文件夹里的。用户文件夹里同品牌同样式的文件优先。
public enum LogoLibrary {
    public static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "webp"]
    private static let folderName = "Logos"
    /// 文件名里品牌和样式名之间的分隔符
    static let variantSeparator: Character = "-"
    static let colorVariantKeywords = ["彩色", "color", "colour"]

    /// 样式偏好按颜色模式分开记：染色模式下选的单色样式，不会影响原色模式下选的彩色样式。
    public static func preferenceKey(brandID: String, isOriginalColor: Bool) -> String {
        isOriginalColor ? "\(brandID)@原色" : brandID
    }
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
        return byID.values.sorted { nameAscending($0.name, $1.name) }
    }

    public static func allEntries() -> [LogoEntry] {
        entries(in: bundledDirectories + [userDirectory])
    }

    /// 把 Logo 按品牌分组。每组里默认 Logo 在前，其余样式按名称排序；品牌之间按名称排序。
    public static func brands(from entries: [LogoEntry]) -> [LogoBrand] {
        Dictionary(grouping: entries.filter { !$0.brandID.isEmpty }, by: \.brandID)
            .map { brandID, group in
                let variants = group.sorted { lhs, rhs in
                    switch (lhs.variant, rhs.variant) {
                    case (nil, _): return true
                    case (_, nil): return false
                    case let (left?, right?): return nameAscending(left, right)
                    }
                }
                return LogoBrand(id: brandID, name: variants[0].brandName, variants: variants)
            }
            .sorted { nameAscending($0.name, $1.name) }
    }

    /// 按中文环境排序，避免 CI 和不同系统语言下样式顺序不一致。
    private static let nameLocale = Locale(identifier: "zh_CN")

    private static func nameAscending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(
            rhs,
            options: [.caseInsensitive, .numeric, .widthInsensitive, .forcedOrdering],
            locale: nameLocale
        ) == .orderedAscending
    }

    /// 按 EXIF 的厂商字段找品牌：厂商名以哪个品牌键开头就用哪个，多个命中取最长的。
    /// 例如 "NIKON CORPORATION" 命中 `Nikon`，"OM Digital Solutions" 命中 `OM Digital` 而不是 `OM`。
    public static func matchBrand(make: String?, in brands: [LogoBrand]) -> LogoBrand? {
        guard let make else { return nil }
        let key = normalized(make)
        guard !key.isEmpty else { return nil }
        return brands
            .filter { key.hasPrefix($0.id) }
            .max { $0.id.count < $1.id.count }
    }

    /// 按厂商字段找 Logo 图片。`preferences` 的键见 `preferenceKey`，值是偏好样式的 id。
    public static func match(
        make: String?, in entries: [LogoEntry], preferences: [String: String] = [:], isOriginalColor: Bool = false
    ) -> LogoEntry? {
        guard let brand = matchBrand(make: make, in: brands(from: entries)) else { return nil }
        let key = preferenceKey(brandID: brand.id, isOriginalColor: isOriginalColor)
        return brand.entry(preferring: preferences[key], isOriginalColor: isOriginalColor)
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
