import Foundation
import ImageIO

public enum MetadataReader {
    private static let exifDateFormat = "yyyy:MM:dd HH:mm:ss"

    /// 读取文件的 EXIF。文件无法识别时抛错；识别成功但没有 EXIF 时返回空的 `PhotoMetadata`。
    public static func read(url: URL) throws -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw BorderMarkError.unreadableImage(url)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return PhotoMetadata()
        }
        return parse(properties: properties)
    }

    /// 纯函数：把 ImageIO 的属性字典转成 `PhotoMetadata`。
    public static func parse(properties: [String: Any]) -> PhotoMetadata {
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]

        return PhotoMetadata(
            make: cleaned(tiff[kCGImagePropertyTIFFMake as String]),
            model: cleaned(tiff[kCGImagePropertyTIFFModel as String]),
            lens: cleaned(exif[kCGImagePropertyExifLensModel as String]),
            focalLength: positive(exif[kCGImagePropertyExifFocalLength as String]),
            focalLength35: positive(exif[kCGImagePropertyExifFocalLenIn35mmFilm as String]),
            fNumber: positive(exif[kCGImagePropertyExifFNumber as String]),
            exposureTime: positive(exif[kCGImagePropertyExifExposureTime as String]),
            iso: isoValue(exif[kCGImagePropertyExifISOSpeedRatings as String]),
            date: dateValue(exif[kCGImagePropertyExifDateTimeOriginal as String]),
            latitude: coordinate(
                gps[kCGImagePropertyGPSLatitude as String],
                ref: gps[kCGImagePropertyGPSLatitudeRef as String],
                negativeRef: "S"
            ),
            longitude: coordinate(
                gps[kCGImagePropertyGPSLongitude as String],
                ref: gps[kCGImagePropertyGPSLongitudeRef as String],
                negativeRef: "W"
            )
        )
    }

    private static func cleaned(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func positive(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let double = number.doubleValue
        return double > 0 && double.isFinite ? double : nil
    }

    private static func isoValue(_ value: Any?) -> Int? {
        if let list = value as? [NSNumber], let first = list.first { return first.intValue }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func dateValue(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = exifDateFormat
        return formatter.date(from: string)
    }

    private static func coordinate(_ value: Any?, ref: Any?, negativeRef: String) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let isNegative = (ref as? String)?.uppercased() == negativeRef
        return isNegative ? -number.doubleValue : number.doubleValue
    }
}
