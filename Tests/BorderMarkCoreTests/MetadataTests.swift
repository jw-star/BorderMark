import Foundation
import ImageIO
import Testing
@testable import BorderMarkCore

@Suite("EXIF 解析")
struct MetadataReaderTests {
    @Test("完整的属性字典解析出所有字段")
    func parsesFullProperties() {
        // Arrange
        let properties: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: ["Make": " SONY ", "Model": "ILCE-7M4"],
            kCGImagePropertyExifDictionary as String: [
                "LensModel": "FE 35mm F1.8",
                "FocalLength": 35,
                "FNumber": 1.8,
                "ExposureTime": 0.008,
                "ISOSpeedRatings": [400],
                "DateTimeOriginal": "2026:10:03 17:42:10",
            ],
            kCGImagePropertyGPSDictionary as String: [
                "Latitude": 39.9, "LatitudeRef": "N", "Longitude": 116.4, "LongitudeRef": "W",
            ],
        ]

        // Act
        let metadata = MetadataReader.parse(properties: properties)

        // Assert
        #expect(metadata.make == "SONY")
        #expect(metadata.model == "ILCE-7M4")
        #expect(metadata.lens == "FE 35mm F1.8")
        #expect(metadata.focalLength == 35)
        #expect(metadata.fNumber == 1.8)
        #expect(metadata.exposureTime == 0.008)
        #expect(metadata.iso == 400)
        #expect(metadata.date != nil)
        #expect(metadata.latitude == 39.9)
        #expect(metadata.longitude == -116.4)
    }

    @Test("没有 EXIF 时返回空元数据而不是报错")
    func emptyPropertiesGiveEmptyMetadata() {
        #expect(MetadataReader.parse(properties: [:]) == PhotoMetadata())
    }

    @Test("零或空白值视为缺失")
    func zeroAndBlankAreMissing() {
        let properties: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: ["Model": "   "],
            kCGImagePropertyExifDictionary as String: ["FNumber": 0],
        ]
        let metadata = MetadataReader.parse(properties: properties)
        #expect(metadata.model == nil)
        #expect(metadata.fNumber == nil)
    }

    @Test("不存在的文件抛出可读错误")
    func unreadableFileThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent/photo.jpg")
        #expect(throws: BorderMarkError.unreadableImage(missing)) {
            try MetadataReader.read(url: missing)
        }
    }
}

@Suite("占位符替换")
struct PlaceholderResolverTests {
    private static let full = PhotoMetadata(
        make: "NIKON CORPORATION", model: "NIKON Z 8", lens: "NIKKOR Z 24-70mm f/2.8 S",
        focalLength: 35, fNumber: 2.8, exposureTime: 1.0 / 250.0, iso: 200,
        date: Date(timeIntervalSince1970: 0), latitude: 39.9042, longitude: 116.4074
    )

    @Test("曝光参数格式化", arguments: [
        ("{FocalLength}", "35mm"),
        ("{FNumber}", "f/2.8"),
        ("{Shutter}", "1/250s"),
        ("{ISO}", "ISO200"),
        ("{Params}", "35mm  f/2.8  1/250s  ISO200"),
        ("{GPS}", "39°54'N 116°24'E"),
    ])
    func formatsExposure(template: String, expected: String) {
        #expect(PlaceholderResolver(metadata: Self.full).resolve(template) == expected)
    }

    @Test("快门文字", arguments: [(2.0, "2s"), (0.5, "1/2s"), (1.3, "1.3s"), (1.0 / 8000.0, "1/8000s")])
    func shutterText(seconds: Double, expected: String) {
        #expect(PlaceholderResolver.shutterText(seconds) == expected)
    }

    @Test("占位符全部为空时整行丢弃")
    func dropsLineWhenAllPlaceholdersEmpty() {
        let resolver = PlaceholderResolver(metadata: PhotoMetadata())
        #expect(resolver.resolve("{Model}  ·  {Params}") == nil)
        #expect(resolver.resolve("© {Author}") == nil)
    }

    @Test("部分缺失时去掉悬空的分隔符")
    func trimsDanglingSeparators() {
        let resolver = PlaceholderResolver(metadata: PhotoMetadata(model: "X100VI"))
        #expect(resolver.resolve("{Model}  ·  {Params}") == "X100VI")
        #expect(resolver.resolve("{Params} | {Model}") == "X100VI")
    }

    @Test("没有占位符的纯文字原样保留")
    func keepsLiteralText() {
        #expect(PlaceholderResolver(metadata: PhotoMetadata()).resolve("SHOT ON FILM") == "SHOT ON FILM")
    }

    @Test("未知占位符按空处理")
    func unknownKeyIsEmpty() {
        #expect(PlaceholderResolver(metadata: Self.full).resolve("{Nope}") == nil)
        #expect(PlaceholderResolver(metadata: Self.full).resolve("{Nope} {Model}") == "NIKON Z 8")
    }

    @Test("手动覆盖优先于 EXIF，并反映到 Params")
    func overridesWin() {
        let options = RenderOptions(fieldOverrides: ["Model": "我的相机", "ISO": "ISO64", "Lens": "  "])
        let resolver = PlaceholderResolver(metadata: Self.full, options: options)
        #expect(resolver.resolve("{Model}") == "我的相机")
        #expect(resolver.resolve("{Params}") == "35mm  f/2.8  1/250s  ISO64")
        #expect(resolver.resolve("{Lens}") == "NIKKOR Z 24-70mm f/2.8 S")
    }

    @Test("署名生成版权行")
    func copyrightFromAuthor() {
        let resolver = PlaceholderResolver(metadata: PhotoMetadata(), options: RenderOptions(author: " 小王 "))
        #expect(resolver.resolve("{Copyright}") == "© 小王")
    }

    @Test("声明支持的占位符都有值可查")
    func supportedKeysAreAllProvided() {
        let values = PlaceholderResolver(metadata: Self.full).values
        for key in PlaceholderResolver.supportedKeys {
            #expect(values[key] != nil, "缺少 \(key)")
        }
    }
}
