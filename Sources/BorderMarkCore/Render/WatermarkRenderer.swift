import CoreGraphics
import Foundation

/// 把"照片 + 元数据 + 模板 + 用户调整"合成一张带边框水印的图。纯函数，可在任意线程调用。
public enum WatermarkRenderer {
    public static func render(
        image: CGImage,
        metadata: PhotoMetadata,
        template: Template,
        options: RenderOptions = RenderOptions(),
        logo: CGImage? = nil
    ) throws -> CGImage {
        let applied = template.applying(options)
        let layout = CanvasLayout(
            photoSize: CGSize(width: image.width, height: image.height),
            border: applied.border
        )
        guard let context = makeContext(size: layout.canvasSize, matching: image) else {
            throw BorderMarkError.renderFailed("无法创建 \(Int(layout.canvasSize.width))×\(Int(layout.canvasSize.height)) 的画布")
        }

        // 翻转成左上角原点，和 CanvasLayout 的坐标一致
        context.translateBy(x: 0, y: layout.canvasSize.height)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high

        BackgroundPainter.paint(applied.background, image: image, layout: layout, in: context)
        drawPhoto(image, style: applied.photo, layout: layout, in: context)

        let painter = ElementPainter(
            layout: layout,
            resolver: PlaceholderResolver(metadata: metadata, options: options),
            fontName: applied.fontName,
            logo: options.isLogoVisible ? logo : nil,
            isLogoTinted: options.isLogoTinted
        )
        applied.elements.forEach { painter.draw($0, in: context) }

        guard let output = context.makeImage() else {
            throw BorderMarkError.renderFailed("无法生成输出图像")
        }
        return output
    }

    private static func makeContext(size: CGSize, matching image: CGImage) -> CGContext? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let fallback = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        // 沿用原图色彩空间（如 Display P3），避免导出偏色
        let space = image.colorSpace.flatMap { $0.model == .rgb && $0.supportsOutput ? $0 : nil } ?? fallback
        return CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }

    private static func drawPhoto(_ image: CGImage, style: PhotoStyle, layout: CanvasLayout, in context: CGContext) {
        let rect = layout.photoRect
        let maxRadius = min(rect.width, rect.height) / 2
        let radius = min(max(0, layout.base * style.cornerRadius), maxRadius)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        if let shadow = style.shadow {
            context.saveGState()
            // 阴影偏移不受 CTM 影响，设备坐标 y 向上，所以向下要取负
            context.setShadow(
                offset: CGSize(width: 0, height: -layout.base * shadow.offsetY),
                blur: layout.base * shadow.radius,
                color: CGColor(gray: 0, alpha: min(max(shadow.opacity, 0), 1))
            )
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawUpright(image, in: rect)
        context.restoreGState()
    }
}
