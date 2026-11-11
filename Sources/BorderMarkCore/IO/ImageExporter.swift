import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg, heic, png

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .png: return "PNG"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .png: return "png"
        }
    }

    public var isLossy: Bool { self != .png }

    var typeIdentifier: CFString {
        switch self {
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .heic: return UTType.heic.identifier as CFString
        case .png: return UTType.png.identifier as CFString
        }
    }
}

public enum ImageExporter {
    private static let uprightOrientation = 1

    /// 写出图片。提供 `sourceURL` 时会把原图的 EXIF / GPS 等元数据一并带过去。
    public static func export(
        _ image: CGImage,
        to url: URL,
        format: ExportFormat,
        quality: Double = 1.0,
        sourceURL: URL? = nil
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.typeIdentifier, 1, nil) else {
            throw BorderMarkError.exportFailed(url)
        }
        let metadata = sourceURL.map(carriedMetadata) ?? [:]
        let settings: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: min(max(quality, 0), 1),
        ]
        let properties = metadata.merging(settings) { _, setting in setting }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw BorderMarkError.exportFailed(url)
        }
    }

    /// 输出文件名：`原名_模板id.扩展名`
    public static func outputURL(for source: URL, templateID: String, format: ExportFormat, in directory: URL) -> URL {
        let stem = source.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(stem)_\(templateID).\(format.fileExtension)")
    }

    /// 原图元数据，去掉已经失效的部分：像素已摆正所以方向归 1，尺寸交给 ImageIO 重新写。
    private static func carriedMetadata(from url: URL) -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return [:] }

        let staleKeys: Set<String> = [
            kCGImagePropertyPixelWidth as String,
            kCGImagePropertyPixelHeight as String,
        ]
        let kept = original.filter { !staleKeys.contains($0.key) }

        let exif = (kept[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]).filter {
            $0.key != (kCGImagePropertyExifPixelXDimension as String)
                && $0.key != (kCGImagePropertyExifPixelYDimension as String)
        }
        let tiff = (kept[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:])
            .merging([kCGImagePropertyTIFFOrientation as String: uprightOrientation]) { _, new in new }

        return kept.merging([
            kCGImagePropertyOrientation as String: uprightOrientation,
            kCGImagePropertyExifDictionary as String: exif,
            kCGImagePropertyTIFFDictionary as String: tiff,
        ]) { _, new in new }
    }
}
