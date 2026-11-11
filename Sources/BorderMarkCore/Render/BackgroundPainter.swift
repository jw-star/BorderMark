import CoreGraphics
import CoreImage

enum BackgroundPainter {
    /// 模糊和取色都在缩小后的图上做：结果肉眼无差别，速度和内存好很多。
    private static let workingMaxDimension: CGFloat = 480
    private static let averageSampleSize = 16
    private static let ciContext = CIContext()

    static func paint(_ background: Background, image: CGImage, layout: CanvasLayout, in context: CGContext) {
        let canvas = CGRect(origin: .zero, size: layout.canvasSize)
        switch background {
        case .solid(let color):
            fill(canvas, with: HexColor.cgColor(color), in: context)

        case .gradient(let from, let to):
            paintGradient(from: HexColor.cgColor(from), to: HexColor.cgColor(to), canvas: canvas, in: context)

        case .blur(let radius, let dim):
            paintBlur(image: image, radius: radius, layout: layout, canvas: canvas, in: context)
            fill(canvas, with: CGColor(gray: 0, alpha: clamp(dim)), in: context)

        case .dominant(let dim):
            fill(canvas, with: averageColor(of: image) ?? CGColor(gray: 0.5, alpha: 1), in: context)
            fill(canvas, with: CGColor(gray: 0, alpha: clamp(dim)), in: context)
        }
    }

    private static func fill(_ rect: CGRect, with color: CGColor, in context: CGContext) {
        context.setFillColor(color)
        context.fill(rect)
    }

    private static func clamp(_ value: Double) -> CGFloat { CGFloat(min(max(value, 0), 1)) }

    private static func paintGradient(from: CGColor, to: CGColor, canvas: CGRect, in context: CGContext) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: [from, to] as CFArray, locations: [0, 1]) else {
            fill(canvas, with: from, in: context)
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: canvas.midX, y: canvas.minY),
            end: CGPoint(x: canvas.midX, y: canvas.maxY),
            options: []
        )
    }

    private static func paintBlur(
        image: CGImage,
        radius: Double,
        layout: CanvasLayout,
        canvas: CGRect,
        in context: CGContext
    ) {
        guard let small = resized(image, maxDimension: workingMaxDimension) else {
            fill(canvas, with: CGColor(gray: 0.2, alpha: 1), in: context)
            return
        }
        let scale = CGFloat(small.width) / CGFloat(image.width)
        let sigma = max(1, layout.base * radius * scale)
        let source = CIImage(cgImage: small)
        let blurred = source.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: source.extent)
        let output = ciContext.createCGImage(blurred, from: source.extent) ?? small
        context.drawUpright(output, in: aspectFill(CGSize(width: output.width, height: output.height), in: canvas))
    }

    private static func aspectFill(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let scale = max(bounds.width / size.width, bounds.height / size.height)
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: bounds.midX - scaled.width / 2,
            y: bounds.midY - scaled.height / 2,
            width: scaled.width,
            height: scaled.height
        )
    }

    static func resized(_ image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let longest = CGFloat(max(image.width, image.height))
        let scale = min(1, maxDimension / longest)
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = bitmapContext(width: width, height: height) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func averageColor(of image: CGImage) -> CGColor? {
        let side = averageSampleSize
        guard let context = bitmapContext(width: side, height: side) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return nil }

        let pixelCount = side * side
        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * side)
        var totals = [0, 0, 0]
        for row in 0..<side {
            for column in 0..<side {
                let offset = row * context.bytesPerRow + column * 4
                totals[0] += Int(bytes[offset])
                totals[1] += Int(bytes[offset + 1])
                totals[2] += Int(bytes[offset + 2])
            }
        }
        let channels = totals.map { CGFloat($0) / CGFloat(pixelCount) / 255 }
        return CGColor(srgbRed: channels[0], green: channels[1], blue: channels[2], alpha: 1)
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}
