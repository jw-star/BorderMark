import CoreGraphics

/// 画布几何：坐标原点在左上角，单位为像素。纯计算，不依赖绘图上下文。
public struct CanvasLayout: Equatable, Sendable {
    public let canvasSize: CGSize
    public let photoRect: CGRect
    /// 所有比例的基准：照片短边
    public let base: CGFloat

    public init(photoSize: CGSize, border: EdgeRatios) {
        let base = min(photoSize.width, photoSize.height)
        let top = (base * border.top).rounded()
        let left = (base * border.left).rounded()
        let bottom = (base * border.bottom).rounded()
        let right = (base * border.right).rounded()

        self.base = base
        self.photoRect = CGRect(x: left, y: top, width: photoSize.width, height: photoSize.height)
        self.canvasSize = CGSize(width: left + photoSize.width + right, height: top + photoSize.height + bottom)
    }

    public func rect(for region: Region) -> CGRect {
        let canvas = CGRect(origin: .zero, size: canvasSize)
        switch region {
        case .canvas:
            return canvas
        case .photo:
            return photoRect
        case .top:
            return CGRect(x: 0, y: 0, width: canvas.width, height: photoRect.minY)
        case .bottom:
            return CGRect(x: 0, y: photoRect.maxY, width: canvas.width, height: canvas.height - photoRect.maxY)
        case .left:
            return CGRect(x: 0, y: 0, width: photoRect.minX, height: canvas.height)
        case .right:
            return CGRect(x: photoRect.maxX, y: 0, width: canvas.width - photoRect.maxX, height: canvas.height)
        }
    }

    /// 在区域内按九宫格对齐摆放一个给定尺寸的盒子；`insetX/insetY` 是相对 `base` 的内缩比例。
    public func place(
        size: CGSize,
        in region: Region,
        h: HAlign,
        v: VAlign,
        insetX: Double = 0,
        insetY: Double = 0
    ) -> CGRect {
        let bounds = rect(for: region).insetBy(dx: base * insetX, dy: base * insetY)
        let x: CGFloat
        switch h {
        case .leading: x = bounds.minX
        case .center: x = bounds.midX - size.width / 2
        case .trailing: x = bounds.maxX - size.width
        }
        let y: CGFloat
        switch v {
        case .top: y = bounds.minY
        case .center: y = bounds.midY - size.height / 2
        case .bottom: y = bounds.maxY - size.height
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
