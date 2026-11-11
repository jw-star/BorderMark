import CoreGraphics
import Foundation

/// 负责把模板里的元素（文字组、平铺水印）画到画布上。
struct ElementPainter {
    /// 品牌名文字代替 Logo 时，字号相对 Logo 高度的比例
    private static let brandTextRatio: CGFloat = 0.72
    /// Logo 宽度最多是高度的几倍
    private static let maxLogoAspect: CGFloat = 4.5
    /// 直接压在照片上的文字加一点投影，保证亮背景上也看得清
    private static let overlayShadowBlurRatio: CGFloat = 0.008
    private static let overlayShadowOffsetRatio: CGFloat = 0.002
    private static let overlayShadowOpacity: CGFloat = 0.45

    let layout: CanvasLayout
    let resolver: PlaceholderResolver
    let fontName: String?
    let logo: CGImage?
    let isLogoTinted: Bool

    func draw(_ element: Element, in context: CGContext) {
        switch element {
        case .group(let group): draw(group, in: context)
        case .stack(let stack): draw(stack, in: context)
        case .tile(let tile): draw(tile, in: context)
        }
    }

    // MARK: - Group

    private enum Piece {
        case text(lines: [MeasuredLine], align: HAlign, spacing: CGFloat)
        case image(CGImage, size: CGSize)
        case divider(color: CGColor, size: CGSize)

        var isDivider: Bool { if case .divider = self { return true } else { return false } }

        var size: CGSize {
            switch self {
            case .text(let lines, _, let spacing):
                let width = lines.map(\.width).max() ?? 0
                let height = lines.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, lines.count - 1))
                return CGSize(width: width, height: height)
            case .image(_, let size), .divider(_, let size):
                return size
            }
        }
    }

    /// 量好尺寸、可以直接画的一行
    private struct Row {
        let pieces: [Piece]
        let sizes: [CGSize]
        let spacing: CGFloat

        var size: CGSize {
            CGSize(
                width: sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, pieces.count - 1)),
                height: sizes.map(\.height).max() ?? 0
            )
        }
    }

    /// 一行里没有任何可画的内容（比如占位符全为空）时返回 `nil`。
    private func row(for items: [GroupItem], spacing: Double) -> Row? {
        let pieces = trimmingDividers(items.compactMap(piece))
        guard !pieces.isEmpty else { return nil }
        return Row(pieces: pieces, sizes: pieces.map(\.size), spacing: layout.base * spacing)
    }

    private func draw(_ group: GroupElement, in context: CGContext) {
        guard let row = row(for: group.items, spacing: group.spacing) else { return }
        let frame = layout.place(
            size: row.size, in: group.region, h: group.h, v: group.v, insetX: group.insetX, insetY: group.insetY
        )
        context.saveGState()
        if group.region == .photo { applyOverlayShadow(to: context) }
        draw(row, in: frame, context: context)
        context.restoreGState()
    }

    private func draw(_ stack: StackElement, in context: CGContext) {
        let rows = stack.rows.compactMap { row(for: $0, spacing: stack.spacing) }
        guard !rows.isEmpty else { return }

        let rowSpacing = layout.base * stack.rowSpacing
        let total = CGSize(
            width: rows.map(\.size.width).max() ?? 0,
            height: rows.map(\.size.height).reduce(0, +) + rowSpacing * CGFloat(rows.count - 1)
        )
        let frame = layout.place(
            size: total, in: stack.region, h: stack.h, v: stack.v, insetX: stack.insetX, insetY: stack.insetY
        )

        context.saveGState()
        if stack.region == .photo { applyOverlayShadow(to: context) }
        var y = frame.minY
        for row in rows {
            let size = row.size
            let x: CGFloat
            switch stack.h {
            case .leading: x = frame.minX
            case .center: x = frame.midX - size.width / 2
            case .trailing: x = frame.maxX - size.width
            }
            draw(row, in: CGRect(origin: CGPoint(x: x, y: y), size: size), context: context)
            y += size.height + rowSpacing
        }
        context.restoreGState()
    }

    /// 把一行从左到右画出来，各项在行内垂直居中。
    private func draw(_ row: Row, in frame: CGRect, context: CGContext) {
        var x = frame.minX
        for (piece, size) in zip(row.pieces, row.sizes) {
            let origin = CGPoint(x: x, y: frame.midY - size.height / 2)
            draw(piece, in: CGRect(origin: origin, size: size), context: context)
            x += size.width + row.spacing
        }
    }

    private func piece(for item: GroupItem) -> Piece? {
        switch item {
        case .text(let lines, let align, let lineSpacing):
            let measured = lines.compactMap { line -> MeasuredLine? in
                guard let text = resolver.resolve(line.text) else { return nil }
                return measure(text, size: line.size, weight: line.weight, color: line.color)
            }
            return measured.isEmpty ? nil : .text(lines: measured, align: align, spacing: layout.base * lineSpacing)

        case .logo(let height, let color):
            let pixelHeight = layout.base * height
            if let logo, logo.height > 0 {
                let image = isLogoTinted ? LogoTint.tinted(logo, with: HexColor.cgColor(color)) : logo
                return .image(image, size: Self.logoSize(for: logo, height: pixelHeight))
            }
            guard let brand = Self.brandName(from: resolver.values["Make"]) else { return nil }
            let line = measure(brand, size: height * Self.brandTextRatio, weight: .bold, color: color)
            return .text(lines: [line], align: .center, spacing: 0)

        case .divider(let height, let width, let color):
            let size = CGSize(width: max(1, layout.base * width), height: layout.base * height)
            return .divider(color: HexColor.cgColor(color), size: size)
        }
    }

    /// 分隔线只有夹在两个内容之间才有意义：去掉首尾的和连续重复的。
    private func trimmingDividers(_ pieces: [Piece]) -> [Piece] {
        let deduplicated = pieces.reduce(into: [Piece]()) { result, piece in
            if piece.isDivider, result.last?.isDivider ?? true { return }
            result.append(piece)
        }
        return deduplicated.last?.isDivider == true ? Array(deduplicated.dropLast()) : deduplicated
    }

    private func draw(_ piece: Piece, in rect: CGRect, context: CGContext) {
        switch piece {
        case .text(let lines, let align, let spacing):
            var y = rect.minY
            for line in lines {
                let x: CGFloat
                switch align {
                case .leading: x = rect.minX
                case .center: x = rect.midX - line.width / 2
                case .trailing: x = rect.maxX - line.width
                }
                TextDrawing.draw(line, at: CGPoint(x: x, y: y), in: context)
                y += line.height + spacing
            }
        case .image(let image, _):
            context.drawUpright(image, in: rect)
        case .divider(let color, _):
            context.setFillColor(color)
            context.fill(rect)
        }
    }

    private func applyOverlayShadow(to context: CGContext) {
        context.setShadow(
            offset: CGSize(width: 0, height: -layout.base * Self.overlayShadowOffsetRatio),
            blur: layout.base * Self.overlayShadowBlurRatio,
            color: CGColor(gray: 0, alpha: Self.overlayShadowOpacity)
        )
    }

    // MARK: - Tile

    private func draw(_ tile: TileElement, in context: CGContext) {
        guard let text = resolver.resolve(tile.text) else { return }
        let line = measure(text, size: tile.size, weight: tile.weight, color: tile.color)
        let stepX = line.width + layout.base * max(0, tile.spacingX)
        let stepY = line.height + layout.base * max(0, tile.spacingY)
        guard stepX > 1, stepY > 1 else { return }

        let rect = layout.rect(for: tile.region)
        let reach = hypot(rect.width, rect.height) / 2

        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.midX, y: rect.midY)
        // 坐标系已翻转，取负才是视觉上的逆时针
        context.rotate(by: -tile.angle * .pi / 180)
        for (row, y) in stride(from: -reach, through: reach, by: stepY).enumerated() {
            let stagger = row.isMultiple(of: 2) ? 0 : stepX / 2
            for x in stride(from: -reach - stagger, through: reach, by: stepX) {
                TextDrawing.draw(line, at: CGPoint(x: x, y: y), in: context)
            }
        }
        context.restoreGState()
    }

    // MARK: - Helpers

    private func measure(_ text: String, size: Double, weight: FontWeight, color: String) -> MeasuredLine {
        TextDrawing.measure(
            text,
            fontName: fontName,
            size: max(1, layout.base * size),
            weight: weight,
            color: HexColor.cgColor(color)
        )
    }

    /// 按给定高度等比缩放；特别长的字标（如 Panasonic）限制最大宽度，整体等比缩小，免得挤占旁边的文字。
    static func logoSize(for logo: CGImage, height: CGFloat) -> CGSize {
        let aspect = CGFloat(logo.width) / CGFloat(logo.height)
        guard aspect > maxLogoAspect else { return CGSize(width: height * aspect, height: height) }
        let width = height * maxLogoAspect
        return CGSize(width: width, height: width / aspect)
    }

    /// "NIKON CORPORATION" → "NIKON"，"Apple" → "APPLE"
    static func brandName(from make: String?) -> String? {
        guard let first = make?.split(separator: " ").first, !first.isEmpty else { return nil }
        return first.uppercased()
    }
}
