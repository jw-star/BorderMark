import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BorderMarkCore

/// 测试用的像素工具
enum Pixels {
    static func solidImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> CGImage {
        let context = try #require(makeContext(width: width, height: height))
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    /// 读取像素，坐标原点在左上角
    static func color(of image: CGImage, x: Int, y: Int) throws -> [Int] {
        let context = try #require(makeContext(width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * image.height)
        let offset = y * context.bytesPerRow + x * 4
        return [Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2])]
    }

    static func isClose(_ lhs: [Int], _ rhs: [Int], tolerance: Int = 6) -> Bool {
        zip(lhs, rhs).allSatisfy { abs($0 - $1) <= tolerance }
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}

@Suite("渲染")
struct WatermarkRendererTests {
    private static let metadata = PhotoMetadata(
        make: "FUJIFILM", model: "X100VI", lens: "23mm F2", focalLength: 23, fNumber: 2,
        exposureTime: 1.0 / 125.0, iso: 400, date: Date(timeIntervalSince1970: 1_700_000_000)
    )
    private static let red = [255, 0, 0]

    @Test("每个内置模板都能渲染，输出尺寸与版式一致", arguments: BuiltinTemplates.all)
    func rendersEveryBuiltin(template: Template) throws {
        let photo = try Pixels.solidImage(width: 600, height: 400, red: 1, green: 0, blue: 0)
        let options = RenderOptions(author: "测试", customText: "你好")

        let output = try WatermarkRenderer.render(
            image: photo, metadata: Self.metadata, template: template, options: options
        )

        let layout = CanvasLayout(photoSize: CGSize(width: 600, height: 400), border: template.border)
        #expect(output.width == Int(layout.canvasSize.width))
        #expect(output.height == Int(layout.canvasSize.height))
    }

    @Test("空元数据也不会失败", arguments: BuiltinTemplates.all)
    func rendersWithoutMetadata(template: Template) throws {
        let photo = try Pixels.solidImage(width: 300, height: 450, red: 0, green: 0, blue: 1)
        #expect(throws: Never.self) {
            try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)
        }
    }

    @Test("白底模板：照片区保持原色，底栏是白色")
    func classicLayoutPixels() throws {
        let photo = try Pixels.solidImage(width: 600, height: 400, red: 1, green: 0, blue: 0)
        let template = Template(id: "t", name: "t", border: EdgeRatios(top: 0, left: 0, bottom: 0.25, right: 0))

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        #expect(output.height == 500)
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 300, y: 200), Self.red))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 300, y: 395), Self.red))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 300, y: 450), [255, 255, 255]))
    }

    @Test("文字确实画在了指定区域")
    func textIsDrawnInRegion() throws {
        let photo = try Pixels.solidImage(width: 600, height: 400, red: 1, green: 0, blue: 0)
        let line = TextLine("██████████", size: 0.2, weight: .bold, color: "#000000")
        let template = Template(
            id: "t", name: "t", border: EdgeRatios(top: 0, left: 0, bottom: 0.5, right: 0),
            elements: [.group(GroupElement(region: .bottom, items: [
                .text(lines: [line], align: .center, lineSpacing: 0),
            ]))]
        )

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        // 底栏正中应被黑色方块字覆盖，底栏边角仍是白色
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 300, y: 500), [0, 0, 0], tolerance: 40))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 5, y: 595), [255, 255, 255]))
    }

    @Test("堆叠元素把各行自上而下排开并各自居中")
    func stackLaysRowsVertically() throws {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 1, green: 0, blue: 0)
        func block(_ color: String, count: Int) -> GroupItem {
            let text = String(repeating: "█", count: count)
            return .text(lines: [TextLine(text, size: 0.1, weight: .bold, color: color)], align: .center, lineSpacing: 0)
        }
        let stack = StackElement(region: .bottom, rowSpacing: 0.05, rows: [
            [block("#0000FF", count: 6)], [block("#00FF00", count: 2)],
        ])
        let template = Template(
            id: "t", name: "t", border: EdgeRatios(top: 0, left: 0, bottom: 1, right: 0), elements: [.stack(stack)]
        )

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        // 底栏 y 400–800，两行整体垂直居中于 y=600：上行蓝、下行绿，都水平居中于 x=200
        let upper = try Pixels.color(of: output, x: 200, y: 572)
        let lower = try Pixels.color(of: output, x: 200, y: 632)
        #expect(upper[2] > 200 && upper[1] < 80, "上行应为蓝色，实际 \(upper)")
        #expect(lower[1] > 200 && lower[2] < 80, "下行应为绿色，实际 \(lower)")
        // 下行比上行窄：上行覆盖到的左侧位置，在下行的高度上应是白底
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 100, y: 632), [255, 255, 255]))
        #expect(try Pixels.color(of: output, x: 100, y: 572)[2] > 200)
    }

    @Test("堆叠元素里内容为空的行不占位置")
    func stackSkipsEmptyRows() throws {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 1, green: 0, blue: 0)
        let visible = GroupItem.text(
            lines: [TextLine("████", size: 0.1, weight: .bold, color: "#0000FF")], align: .center, lineSpacing: 0
        )
        let empty = GroupItem.text(lines: [TextLine("{Lens}", size: 0.1, color: "#00FF00")], align: .center, lineSpacing: 0)
        let template = Template(
            id: "t", name: "t", border: EdgeRatios(top: 0, left: 0, bottom: 1, right: 0),
            elements: [.stack(StackElement(region: .bottom, rowSpacing: 0.2, rows: [[empty], [visible]]))]
        )

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        // 只剩一行时，它应正好在底栏正中
        #expect(try Pixels.color(of: output, x: 200, y: 600)[2] > 200)
    }

    @Test("圆角把照片四角裁掉，露出背景")
    func cornerRadiusClipsPhoto() throws {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 1, green: 0, blue: 0)
        let template = Template(
            id: "t", name: "t", border: EdgeRatios(all: 0.1),
            background: .solid(color: "#00FF00"), photo: PhotoStyle(cornerRadius: 0.2)
        )

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        #expect(Pixels.isClose(try Pixels.color(of: output, x: 43, y: 43), [0, 255, 0]))
        #expect(Pixels.isClose(try Pixels.color(of: output, x: 240, y: 240), Self.red))
    }

    @Test("主色背景取自照片颜色")
    func dominantBackgroundMatchesPhoto() throws {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 0, green: 0, blue: 1)
        let template = Template(id: "t", name: "t", border: EdgeRatios(all: 0.1), background: .dominant(dim: 0))

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        #expect(Pixels.isClose(try Pixels.color(of: output, x: 5, y: 5), [0, 0, 255]))
    }

    @Test("模糊背景铺满整个画布")
    func blurBackgroundFillsCanvas() throws {
        let photo = try Pixels.solidImage(width: 400, height: 300, red: 0, green: 1, blue: 0)
        let template = Template(id: "t", name: "t", border: EdgeRatios(all: 0.2), background: .blur(radius: 0.05, dim: 0))

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        for point in [(2, 2), (output.width - 3, 2), (2, output.height - 3), (output.width - 3, output.height - 3)] {
            #expect(Pixels.isClose(try Pixels.color(of: output, x: point.0, y: point.1), [0, 255, 0], tolerance: 12))
        }
    }

    @Test("平铺水印改变了照片区域的像素")
    func tileDrawsOverPhoto() throws {
        let photo = try Pixels.solidImage(width: 400, height: 400, red: 0, green: 0, blue: 0)
        let tile = TileElement(text: "████", size: 0.1, color: "#FFFFFF", angle: 0, spacingX: 0, spacingY: 0)
        let template = Template(id: "t", name: "t", elements: [.tile(tile)])

        let output = try WatermarkRenderer.render(image: photo, metadata: PhotoMetadata(), template: template)

        let center = try Pixels.color(of: output, x: 200, y: 215)
        #expect(center[0] > 200)
    }

    @Test("品牌名从厂商字段提取", arguments: [
        ("NIKON CORPORATION", "NIKON"), ("Apple", "APPLE"), ("LEICA CAMERA AG", "LEICA"),
    ])
    func brandName(make: String, expected: String) {
        #expect(ElementPainter.brandName(from: make) == expected)
    }

    @Test("没有厂商信息就没有品牌名")
    func brandNameMissing() {
        #expect(ElementPainter.brandName(from: nil) == nil)
        #expect(ElementPainter.brandName(from: "") == nil)
    }
}

@Suite("导入导出")
struct ImageIOTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func writeSource(orientation: Int = 1) throws -> URL {
        let url = directory.appendingPathComponent("source.jpg")
        let image = try Pixels.solidImage(width: 400, height: 200, red: 1, green: 0, blue: 0)
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let properties: [String: Any] = [
            kCGImagePropertyOrientation as String: orientation,
            kCGImagePropertyTIFFDictionary as String: ["Make": "Canon", "Model": "EOS R5"],
            kCGImagePropertyExifDictionary as String: ["FNumber": 4.0, "ISOSpeedRatings": [100]],
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test("读取写入文件的 EXIF")
    func readsMetadataFromFile() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let metadata = try MetadataReader.read(url: try writeSource())
        #expect(metadata.model == "EOS R5")
        #expect(metadata.fNumber == 4)
        #expect(metadata.iso == 100)
    }

    @Test("加载时按 EXIF 方向摆正，并支持降采样")
    func loadAppliesOrientationAndDownsamples() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let rotated = try writeSource(orientation: 6)

        let full = try ImageLoader.load(url: rotated)
        #expect(full.width == 200)
        #expect(full.height == 400)

        let small = try ImageLoader.load(url: rotated, maxPixelSize: 100)
        #expect(max(small.width, small.height) == 100)
    }

    @Test("导出后保留原图 EXIF，方向归正", arguments: ExportFormat.allCases)
    func exportKeepsMetadata(format: ExportFormat) throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try writeSource(orientation: 6)
        let image = try ImageLoader.load(url: source)
        let output = ImageExporter.outputURL(for: source, templateID: "classic-white", format: format, in: directory)

        try ImageExporter.export(image, to: output, format: format, sourceURL: source)

        #expect(output.lastPathComponent == "source_classic-white.\(format.fileExtension)")
        #expect(try MetadataReader.read(url: output).model == "EOS R5")
        let reloaded = try ImageLoader.load(url: output)
        #expect(reloaded.width == 200)
        #expect(reloaded.height == 400)
    }

    @Test("写不进去的路径抛出导出错误")
    func exportToInvalidPathThrows() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = try Pixels.solidImage(width: 10, height: 10, red: 0, green: 0, blue: 0)
        let invalid = URL(fileURLWithPath: "/nonexistent-dir/out.jpg")
        #expect(throws: BorderMarkError.exportFailed(invalid)) {
            try ImageExporter.export(image, to: invalid, format: .jpeg)
        }
    }

    @Test("支持的扩展名不区分大小写")
    func supportedExtensions() {
        #expect(ImageLoader.isSupported(URL(fileURLWithPath: "/a/b.JPG")))
        #expect(ImageLoader.isSupported(URL(fileURLWithPath: "/a/b.heic")))
        #expect(!ImageLoader.isSupported(URL(fileURLWithPath: "/a/b.txt")))
    }
}
