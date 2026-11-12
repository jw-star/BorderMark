import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BorderMarkCore

@Suite("Logo 库")
struct LogoLibraryTests {
    private static func entries(_ names: [String]) -> [LogoEntry] {
        names.map { LogoEntry(url: URL(fileURLWithPath: "/logos/\($0).png")) }
    }

    @Test("按厂商字段匹配品牌", arguments: [
        ("NIKON CORPORATION", "Nikon"),
        ("Canon", "Canon"),
        ("SONY", "SONY"),
        ("OM Digital Solutions", "OM Digital"),
        ("LEICA CAMERA AG", "Leica"),
    ])
    func matchesMake(make: String, expected: String) {
        let library = Self.entries(["Nikon", "Canon", "SONY", "OM", "OM Digital", "Leica"])
        #expect(LogoLibrary.match(make: make, in: library)?.name == expected)
    }

    @Test("没有对应品牌或没有厂商信息时不匹配", arguments: ["Phase One", "", "   "])
    func noMatch(make: String) {
        #expect(LogoLibrary.match(make: make, in: Self.entries(["Nikon", "Canon"])) == nil)
    }

    @Test("厂商为空值时不匹配")
    func nilMakeDoesNotMatch() {
        #expect(LogoLibrary.match(make: nil, in: Self.entries(["Nikon"])) == nil)
    }

    @Test("扫描目录：只收图片，后面的目录覆盖前面的同名品牌")
    func scansDirectoriesWithOverride() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundled = root.appendingPathComponent("bundled")
        let user = root.appendingPathComponent("user")
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for file in [bundled.appendingPathComponent("Nikon.png"), bundled.appendingPathComponent("SONY.png"),
                     bundled.appendingPathComponent("notes.txt"), user.appendingPathComponent("nikon.PNG")] {
            try Data().write(to: file)
        }

        let entries = LogoLibrary.entries(in: [bundled, user, root.appendingPathComponent("missing")])

        #expect(entries.map(\.id) == ["nikon", "sony"])
        #expect(entries.first?.url.deletingLastPathComponent().lastPathComponent == "user")
    }

    @Test("文件名解析出品牌和样式", arguments: [
        ("Nikon", "nikon", "Nikon", nil as String?, "nikon"),
        ("Nikon-黄标", "nikon", "Nikon", "黄标", "nikon-黄标"),
        ("Leica - Red Dot", "leica", "Leica", "Red Dot", "leica-reddot"),
        ("OM Digital-OM SYSTEM", "omdigital", "OM Digital", "OM SYSTEM", "omdigital-omsystem"),
        ("Nikon-", "nikon", "Nikon", nil, "nikon"),
    ])
    func parsesVariant(stem: String, brandID: String, brandName: String, variant: String?, id: String) {
        let entry = LogoEntry(url: URL(fileURLWithPath: "/logos/\(stem).png"))
        #expect(entry.brandID == brandID)
        #expect(entry.brandName == brandName)
        #expect(entry.variant == variant)
        #expect(entry.id == id)
    }

    @Test("按品牌分组：默认样式在前，其余按名称排序")
    func groupsByBrand() {
        let brands = LogoLibrary.brands(from: Self.entries(["Nikon-黄标", "SONY", "Nikon", "Nikon-白底", "Leica-红标"]))

        #expect(brands.map(\.name) == ["Leica", "Nikon", "SONY"])
        #expect(brands[1].variants.map(\.variantName) == ["默认", "白底", "黄标"])
        // 没有默认 Logo 的品牌，用第一个样式当默认
        #expect(brands[0].defaultEntry.variant == "红标")
    }

    @Test("自动匹配按品牌偏好选样式，偏好失效时回到默认")
    func matchUsesPreference() {
        let library = Self.entries(["Nikon", "Nikon-黄标", "SONY"])

        #expect(LogoLibrary.match(make: "NIKON CORPORATION", in: library)?.name == "Nikon")
        #expect(LogoLibrary.match(
            make: "NIKON CORPORATION", in: library, preferences: ["nikon": "nikon-黄标"]
        )?.name == "Nikon-黄标")
        #expect(LogoLibrary.match(
            make: "NIKON CORPORATION", in: library, preferences: ["nikon": "nikon-已删除"]
        )?.name == "Nikon")
        // 偏好只作用于对应品牌
        #expect(LogoLibrary.match(make: "SONY", in: library, preferences: ["nikon": "nikon-黄标"])?.name == "SONY")
    }

    @Test("样式文件不会被当成另一个品牌去匹配厂商")
    func variantsDoNotBecomeBrands() {
        let library = Self.entries(["Nikon-黄标"])
        #expect(LogoLibrary.match(make: "NIKON CORPORATION", in: library)?.name == "Nikon-黄标")
        #expect(LogoLibrary.brands(from: library).map(\.id) == ["nikon"])
    }

    @Test("用户文件夹里同品牌同样式的文件覆盖内置的，不同样式并存")
    func userVariantsOverrideAndCoexist() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundled = root.appendingPathComponent("bundled")
        let user = root.appendingPathComponent("user")
        try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for file in [bundled.appendingPathComponent("Nikon.png"), user.appendingPathComponent("Nikon.png"),
                     user.appendingPathComponent("Nikon-黄标.png")] {
            try Data().write(to: file)
        }

        let brand = try #require(LogoLibrary.brands(from: LogoLibrary.entries(in: [bundled, user])).first)

        #expect(brand.variants.map(\.variantName) == ["默认", "黄标"])
        #expect(brand.defaultEntry.url.deletingLastPathComponent().lastPathComponent == "user")
    }

    @Test("样式名含“彩色”或 color 的是彩色样式", arguments: [
        ("Nikon-彩色", true), ("Nikon-Color", true), ("Leica-red colour", true), ("Nikon", false), ("Nikon-黄标", false),
    ])
    func detectsColorVariant(stem: String, isColor: Bool) {
        #expect(LogoEntry(url: URL(fileURLWithPath: "/logos/\(stem).png")).isColor == isColor)
    }

    @Test("染色模式不提供彩色样式，原色模式提供全部")
    func variantsDependOnColorMode() throws {
        let brand = try #require(LogoLibrary.brands(from: Self.entries(["Nikon", "Nikon-彩色", "Nikon-白底"])).first)

        #expect(brand.variants(isOriginalColor: false).map(\.variantName) == ["默认", "白底"])
        #expect(brand.variants(isOriginalColor: true).map(\.variantName) == ["默认", "白底", "彩色"])
    }

    @Test("原色模式默认用彩色样式，染色模式默认用默认样式")
    func colorModePicksDefaultVariant() {
        let library = Self.entries(["Nikon", "Nikon-彩色"])

        #expect(LogoLibrary.match(make: "NIKON", in: library)?.name == "Nikon")
        #expect(LogoLibrary.match(make: "NIKON", in: library, isOriginalColor: true)?.name == "Nikon-彩色")
    }

    @Test("两种颜色模式的样式偏好分开记")
    func preferencesAreSeparatedByColorMode() {
        let library = Self.entries(["Nikon", "Nikon-彩色", "Nikon-白底"])
        let preferences = [
            LogoLibrary.preferenceKey(brandID: "nikon", isOriginalColor: false): "nikon-白底",
            LogoLibrary.preferenceKey(brandID: "nikon", isOriginalColor: true): "nikon",
        ]

        #expect(LogoLibrary.match(make: "NIKON", in: library, preferences: preferences)?.name == "Nikon-白底")
        // 原色模式下明确选了默认（单色）样式，就不再自动换成彩色
        #expect(LogoLibrary.match(
            make: "NIKON", in: library, preferences: preferences, isOriginalColor: true
        )?.name == "Nikon")
    }

    @Test("染色模式下偏好是彩色样式时不采用")
    func tintModeIgnoresColorPreference() {
        let library = Self.entries(["Nikon", "Nikon-彩色"])
        let preferences = [LogoLibrary.preferenceKey(brandID: "nikon", isOriginalColor: false): "nikon-彩色"]
        #expect(LogoLibrary.match(make: "NIKON", in: library, preferences: preferences)?.name == "Nikon")
    }

    @Test("只有彩色样式的品牌，染色模式下也能用")
    func colorOnlyBrandStillAvailable() {
        #expect(LogoLibrary.match(make: "NIKON", in: Self.entries(["Nikon-彩色"]))?.name == "Nikon-彩色")
    }

    @Test("内置 Logo：带彩色样式的品牌都有单色默认样式")
    func bundledColorVariantsHaveMonochromeDefault() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BorderMarkCore/Resources/Logos")
        let brands = LogoLibrary.brands(from: LogoLibrary.entries(in: [source]))

        let withColor = brands.filter { $0.variants.contains(where: \.isColor) }
        #expect(withColor.count >= 15)
        for brand in withColor {
            #expect(!brand.defaultEntry.isColor, "\(brand.name) 缺少单色默认样式")
        }
    }

    @Test("应用自带的 Logo 资源能被找到并解码")
    func bundledLogosAreLoadable() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BorderMarkCore/Resources/Logos")

        let entries = LogoLibrary.entries(in: [source])

        #expect(entries.count >= 15)
        for entry in entries {
            let image = try ImageLoader.load(url: entry.url)
            #expect(LogoTint.hasAlpha(image), "\(entry.name) 应带透明通道，才能跟随文字颜色")
        }
    }
}

@Suite("Logo 渲染")
struct LogoRenderTests {
    /// 上半透明、下半不透明红色的 Logo
    private static func halfTransparentLogo() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        return try #require(context.makeImage())
    }

    private static let template = Template(
        id: "t", name: "t", border: EdgeRatios(top: 0, left: 0, bottom: 0.5, right: 0),
        elements: [.group(GroupElement(region: .bottom, items: [.logo(height: 0.4, color: "#0000FF")]))]
    )

    private static func render(options: RenderOptions) throws -> CGImage {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 0, green: 0, blue: 0)
        return try WatermarkRenderer.render(
            image: photo, metadata: PhotoMetadata(), template: template, options: options, logo: try halfTransparentLogo()
        )
    }

    @Test("着色开启：不透明部分变成模板颜色，透明部分露出背景")
    func tintsOpaquePixels() throws {
        let output = try Self.render(options: RenderOptions())
        // 底栏 y 400–600，Logo 高 160 居中于 y 420–580；图片下半（y 500–580）不透明
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 200, y: 540), [0, 0, 255]))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 200, y: 460), [255, 255, 255]))
    }

    @Test("着色关闭：保留 Logo 原色")
    func keepsOriginalColorWhenTintDisabled() throws {
        let output = try Self.render(options: RenderOptions(isLogoTinted: false))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 200, y: 540), [255, 0, 0]))
    }

    @Test("自定义 Logo 颜色生效")
    func customLogoColor() throws {
        let output = try Self.render(options: RenderOptions(logoColor: "#00FF00"))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 200, y: 540), [0, 255, 0]))
    }

    @Test("隐藏 Logo 时不画图片")
    func hiddenLogoDrawsNothing() throws {
        let output = try Self.render(options: RenderOptions(isLogoVisible: false))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 200, y: 540), [255, 255, 255]))
    }

    @Test("普通 Logo 按高度等比缩放，超长字标限制宽度后等比缩小")
    func logoSizeCapsVeryWideWordmarks() throws {
        let square = try Pixels.solidImage(width: 100, height: 100, red: 0, green: 0, blue: 0)
        let wide = try Pixels.solidImage(width: 900, height: 100, red: 0, green: 0, blue: 0)

        #expect(ElementPainter.logoSize(for: square, height: 40) == CGSize(width: 40, height: 40))
        #expect(ElementPainter.logoSize(for: wide, height: 40) == CGSize(width: 180, height: 20))
    }

    @Test("彩色方块徽章放大，彩色长字标不再被缩矮")
    func colorLogosDrawLargerThanMonochrome() throws {
        let badge = try Pixels.solidImage(width: 100, height: 100, red: 1, green: 0.85, blue: 0)
        let wordmark = try Pixels.solidImage(width: 650, height: 100, red: 0, green: 0.2, blue: 0.8)

        let badgeSize = ElementPainter.logoSize(for: badge, height: 40)
        #expect(badgeSize.height > 40)
        #expect(abs(badgeSize.width - badgeSize.height) < 0.5)

        let wordmarkSize = ElementPainter.logoSize(for: wordmark, height: 40)
        #expect(abs(wordmarkSize.height - 40) < 0.5)
        #expect(abs(wordmarkSize.width - 260) < 0.5)
    }

    @Test("没有透明通道的图不着色")
    func opaqueLogoIsNotTinted() throws {
        let opaque = try Pixels.solidImage(width: 10, height: 10, red: 1, green: 0, blue: 0)
        let tinted = LogoTint.tinted(opaque, with: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        #expect(Pixels.isClose(try Pixels.color(of: tinted, x: 5, y: 5), [255, 0, 0]))
    }
}
