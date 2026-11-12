import AppKit
import SwiftUI

/// 可缩放、可拖动的图片视图。“适合”模式整张放进窗口；“100%”模式下一个图片像素对应一个屏幕像素。
/// 单击切换两种模式（以点击位置为中心放大），触控板双指捏合自由缩放，拖动或双指滑动平移。
struct ZoomableImageView: NSViewRepresentable {
    let image: CGImage
    let isActualSize: Bool
    /// 单击时回调，参数是点击位置在图片上的相对坐标（0–1）
    let onToggle: (CGPoint) -> Void

    func makeNSView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        view.onClick = onToggle
        return view
    }

    func updateNSView(_ view: ZoomScrollView, context: Context) {
        view.onClick = onToggle
        view.show(image, isActualSize: isActualSize)
    }
}

final class ZoomScrollView: NSScrollView {
    private static let minMagnification: CGFloat = 0.02
    private static let maxMagnification: CGFloat = 8

    var onClick: ((CGPoint) -> Void)?
    private let imageView = NSImageView()
    private var currentImage: CGImage?
    private var isActualSize = false
    /// 下一次切到 100% 时要居中的相对位置
    private var pendingFocus = CGPoint(x: 0.5, y: 0.5)
    private var dragStart: (mouse: CGPoint, origin: CGPoint)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        contentView = CenteringClipView()
        drawsBackground = false
        contentView.drawsBackground = false
        hasHorizontalScroller = true
        hasVerticalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        allowsMagnification = true
        minMagnification = Self.minMagnification
        maxMagnification = Self.maxMagnification
        imageView.imageScaling = .scaleAxesIndependently
        documentView = imageView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// 1 个图片像素在屏幕上占多少个点
    private var pointsPerPixel: CGFloat { 1 / (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2) }

    func show(_ image: CGImage, isActualSize: Bool) {
        let imageChanged = image !== currentImage
        let modeChanged = isActualSize != self.isActualSize
        guard imageChanged || modeChanged else { return }
        currentImage = image
        self.isActualSize = isActualSize

        let size = CGSize(width: CGFloat(image.width) * pointsPerPixel, height: CGFloat(image.height) * pointsPerPixel)
        if imageChanged {
            imageView.image = NSImage(cgImage: image, size: size)
            imageView.frame = CGRect(origin: .zero, size: size)
        }
        isActualSize ? zoomToActualSize() : zoomToFit()
    }

    override func layout() {
        super.layout()
        if !isActualSize { zoomToFit() }
    }

    private func zoomToFit() {
        let document = imageView.frame.size
        guard document.width > 0, document.height > 0, bounds.width > 0, bounds.height > 0 else { return }
        magnification = min(bounds.width / document.width, bounds.height / document.height, 1)
    }

    private func zoomToActualSize() {
        let document = imageView.frame.size
        let focus = CGPoint(x: document.width * pendingFocus.x, y: document.height * pendingFocus.y)
        setMagnification(1, centeredAt: focus)
        pendingFocus = CGPoint(x: 0.5, y: 0.5)
    }

    // MARK: - 鼠标：单击切换，拖动平移

    override func mouseDown(with event: NSEvent) {
        dragStart = (event.locationInWindow, contentView.bounds.origin)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let delta = CGPoint(
            x: (event.locationInWindow.x - start.mouse.x) / magnification,
            y: (event.locationInWindow.y - start.mouse.y) / magnification
        )
        contentView.scroll(to: CGPoint(x: start.origin.x - delta.x, y: start.origin.y - delta.y))
        reflectScrolledClipView(contentView)
        NSCursor.closedHand.set()
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil; NSCursor.arrow.set() }
        guard let start = dragStart, event.clickCount == 1,
              hypot(event.locationInWindow.x - start.mouse.x, event.locationInWindow.y - start.mouse.y) < 4
        else { return }
        let point = imageView.convert(event.locationInWindow, from: nil)
        let size = imageView.frame.size
        guard size.width > 0, size.height > 0 else { return }
        let focus = CGPoint(x: min(max(point.x / size.width, 0), 1), y: min(max(point.y / size.height, 0), 1))
        pendingFocus = focus
        onClick?(focus)
    }
}

/// 图片比窗口小时让它居中，而不是贴在左下角。
private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let document = documentView?.frame else { return rect }
        if rect.width > document.width { rect.origin.x = (document.width - rect.width) / 2 }
        if rect.height > document.height { rect.origin.y = (document.height - rect.height) / 2 }
        return rect
    }
}
