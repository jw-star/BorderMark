import CoreGraphics
import Foundation
import ImageIO

public enum ImageLoader {
    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp",
        "dng", "arw", "cr2", "cr3", "nef", "raf", "orf", "rw2",
    ]

    public static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// 解码图片并按 EXIF 方向摆正。`maxPixelSize` 为 `nil` 时按原始分辨率解码，否则降采样到该长边。
    public static func load(url: URL, maxPixelSize: Int? = nil) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw BorderMarkError.unreadableImage(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let width = (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue ?? 0
        let fullSize = max(width, height)
        guard fullSize > 0 else { throw BorderMarkError.unreadableImage(url) }

        // 用缩略图接口解码：它会顺带应用 EXIF 方向，并且降采样时不必先解出整张大图
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize ?? fullSize, fullSize),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw BorderMarkError.unreadableImage(url)
        }
        return image
    }
}
