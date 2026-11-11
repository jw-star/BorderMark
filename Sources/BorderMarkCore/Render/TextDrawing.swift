import AppKit
import CoreText

struct MeasuredLine {
    let line: CTLine
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat

    var height: CGFloat { ascent + descent }
}

enum TextDrawing {
    static func font(name: String?, size: CGFloat, weight: FontWeight) -> CTFont {
        if let name, !name.isEmpty,
           let custom = NSFontManager.shared.font(
               withFamily: name,
               traits: [],
               weight: fontManagerWeight(weight),
               size: size
           ) {
            return custom as CTFont
        }
        return NSFont.systemFont(ofSize: size, weight: systemWeight(weight)) as CTFont
    }

    static func measure(
        _ string: String,
        fontName: String?,
        size: CGFloat,
        weight: FontWeight,
        color: CGColor
    ) -> MeasuredLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(name: fontName, size: size, weight: weight),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        return MeasuredLine(line: line, width: width, ascent: ascent, descent: descent)
    }

    /// 在"左上角为原点"的翻转坐标系里绘制一行，`topLeft` 是行框左上角。
    static func draw(_ measured: MeasuredLine, at topLeft: CGPoint, in context: CGContext) {
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: topLeft.x, y: topLeft.y + measured.ascent)
        CTLineDraw(measured.line, context)
    }

    private static func systemWeight(_ weight: FontWeight) -> NSFont.Weight {
        switch weight {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    /// NSFontManager 的字重刻度是 0–15，5 为常规，9 为粗体。
    private static func fontManagerWeight(_ weight: FontWeight) -> Int {
        switch weight {
        case .light: return 3
        case .regular: return 5
        case .medium: return 6
        case .semibold: return 8
        case .bold: return 9
        }
    }
}

extension CGContext {
    /// 在翻转坐标系里正向绘制图片。
    func drawUpright(_ image: CGImage, in rect: CGRect) {
        saveGState()
        translateBy(x: rect.minX, y: rect.maxY)
        scaleBy(x: 1, y: -1)
        draw(image, in: CGRect(origin: .zero, size: rect.size))
        restoreGState()
    }
}
