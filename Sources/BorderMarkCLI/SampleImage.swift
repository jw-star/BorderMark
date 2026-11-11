import BorderMarkCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 生成一张带完整 EXIF 的示例照片，用来在没有真实照片时检查模板效果。
enum SampleImage {
    static var exifProperties: [String: Any] { [
        kCGImagePropertyTIFFDictionary as String: [
            kCGImagePropertyTIFFMake as String: "NIKON CORPORATION",
            kCGImagePropertyTIFFModel as String: "NIKON Z 8",
        ],
        kCGImagePropertyExifDictionary as String: [
            kCGImagePropertyExifLensModel as String: "NIKKOR Z 24-70mm f/2.8 S",
            kCGImagePropertyExifFocalLength as String: 35,
            kCGImagePropertyExifFNumber as String: 2.8,
            kCGImagePropertyExifExposureTime as String: 1.0 / 250.0,
            kCGImagePropertyExifISOSpeedRatings as String: [200],
            kCGImagePropertyExifDateTimeOriginal as String: "2026:10:03 17:42:10",
        ],
    ] }

    static func write(to url: URL, width: Int = 3000, height: Int = 2000) throws {
        guard let image = draw(width: width, height: height),
              let destination = CGImageDestinationCreateWithURL(
                  url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
              )
        else { throw BorderMarkError.exportFailed(url) }

        CGImageDestinationAddImage(destination, image, exifProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw BorderMarkError.exportFailed(url) }
    }

    /// 一幅简单的"日落山景"：渐变天空、太阳、三层山。
    private static func draw(width: Int, height: Int) -> CGImage? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let w = CGFloat(width)
        let h = CGFloat(height)
        let sky = [
            CGColor(srgbRed: 0.98, green: 0.62, blue: 0.36, alpha: 1),
            CGColor(srgbRed: 0.33, green: 0.36, blue: 0.62, alpha: 1),
        ]
        if let gradient = CGGradient(colorsSpace: space, colors: sky as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h * 0.3), end: CGPoint(x: 0, y: h), options: [
                .drawsBeforeStartLocation, .drawsAfterEndLocation,
            ])
        }

        context.setFillColor(CGColor(srgbRed: 1, green: 0.9, blue: 0.7, alpha: 1))
        context.fillEllipse(in: CGRect(x: w * 0.62, y: h * 0.42, width: h * 0.22, height: h * 0.22))

        let ridges: [(base: CGFloat, amplitude: CGFloat, color: CGColor)] = [
            (0.42, 0.10, CGColor(srgbRed: 0.42, green: 0.33, blue: 0.48, alpha: 1)),
            (0.30, 0.09, CGColor(srgbRed: 0.25, green: 0.22, blue: 0.36, alpha: 1)),
            (0.17, 0.07, CGColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1)),
        ]
        for (index, ridge) in ridges.enumerated() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            for step in 0...120 {
                let t = CGFloat(step) / 120
                let wave = sin(t * 9 + CGFloat(index) * 2) * 0.6 + sin(t * 23 + CGFloat(index)) * 0.4
                path.addLine(to: CGPoint(x: t * w, y: h * (ridge.base + ridge.amplitude * wave)))
            }
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(ridge.color)
            context.fillPath()
        }
        return context.makeImage()
    }
}
