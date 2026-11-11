import Foundation

/// 用户在界面上对模板做的调整。不修改模板本身，通过 `Template.applying(_:)` 得到一份新模板。
public struct RenderOptions: Equatable, Sendable {
    public var borderScale: Double
    public var textScale: Double
    public var background: Background?
    public var textColor: String?
    public var cornerRadius: Double?
    public var isShadowEnabled: Bool?
    public var isLogoVisible: Bool
    /// 把带透明通道的 Logo 染成指定颜色；关闭则保留 Logo 原色
    public var isLogoTinted: Bool
    /// Logo 的颜色；`nil` 表示跟随文字颜色
    public var logoColor: String?
    public var fontName: String?
    /// 统一所有文字的粗细；`nil` 表示各行用模板自己的设置
    public var fontWeight: FontWeight?
    public var author: String
    public var customText: String
    /// 手动覆盖占位符的值，键为占位符名（如 `Model`）
    public var fieldOverrides: [String: String]
    /// 改写模板里某一行文字的内容，键为 `Template.textLineSlots` 里的行号；空串表示这一行不显示
    public var lineOverrides: [Int: String]

    public init(
        borderScale: Double = 1,
        textScale: Double = 1,
        background: Background? = nil,
        textColor: String? = nil,
        cornerRadius: Double? = nil,
        isShadowEnabled: Bool? = nil,
        isLogoVisible: Bool = true,
        isLogoTinted: Bool = true,
        logoColor: String? = nil,
        fontName: String? = nil,
        fontWeight: FontWeight? = nil,
        author: String = "",
        customText: String = "",
        fieldOverrides: [String: String] = [:],
        lineOverrides: [Int: String] = [:]
    ) {
        self.borderScale = borderScale
        self.textScale = textScale
        self.background = background
        self.textColor = textColor
        self.cornerRadius = cornerRadius
        self.isShadowEnabled = isShadowEnabled
        self.isLogoVisible = isLogoVisible
        self.isLogoTinted = isLogoTinted
        self.logoColor = logoColor
        self.fontName = fontName
        self.fontWeight = fontWeight
        self.author = author
        self.customText = customText
        self.fieldOverrides = fieldOverrides
        self.lineOverrides = lineOverrides
    }
}

/// 模板里的一行文字及其位置，供界面逐行编辑。
public struct TextLineSlot: Identifiable, Equatable, Sendable {
    /// 行号：按 元素 → 组内项目 → 行 的顺序从 0 编号
    public let id: Int
    public let region: Region
    public let h: HAlign
    /// 在所属文字块里是第几行（从 0 起）
    public let row: Int
    public let text: String
}

extension Template {
    /// 返回套用用户调整后的新模板。
    public func applying(_ options: RenderOptions) -> Template {
        var nextLineIndex = 0
        let adjustedElements = elements.map { element -> Element in
            let result = element.applying(options, firstLineIndex: nextLineIndex)
            nextLineIndex += element.textLineCount
            return result
        }
        return Template(
            id: id,
            name: name,
            summary: summary,
            border: border.scaled(by: max(0, options.borderScale)),
            background: options.background ?? background,
            photo: PhotoStyle(
                cornerRadius: options.cornerRadius ?? photo.cornerRadius,
                shadow: resolvedShadow(options.isShadowEnabled)
            ),
            fontName: options.fontName ?? fontName,
            elements: adjustedElements
        )
    }

    /// 这个模式里有没有 Logo 位置。没有的话，选什么 Logo 都不会显示。
    public var hasLogo: Bool {
        elements.contains { element in
            element.items.contains { if case .logo = $0 { return true } else { return false } }
        }
    }

    /// 模板里所有可编辑的文字行。行号与 `RenderOptions.lineOverrides` 的键对应。
    public var textLineSlots: [TextLineSlot] {
        var slots: [TextLineSlot] = []
        for element in elements {
            guard let placement = element.placement else { continue }
            var row = 0
            for item in element.items {
                guard case .text(let lines, _, _) = item else { continue }
                for line in lines {
                    slots.append(TextLineSlot(
                        id: slots.count, region: placement.region, h: placement.h, row: row, text: line.text
                    ))
                    row += 1
                }
            }
        }
        return slots
    }

    private func resolvedShadow(_ isEnabled: Bool?) -> ShadowStyle? {
        switch isEnabled {
        case .none: return photo.shadow
        case .some(true): return photo.shadow ?? .standard
        case .some(false): return nil
        }
    }
}

extension Element {
    /// 元素里的所有项目，按行号顺序展开（堆叠元素逐行拼接）。平铺水印没有项目。
    var items: [GroupItem] {
        switch self {
        case .group(let group): return group.items
        case .stack(let stack): return stack.rows.flatMap { $0 }
        case .tile: return []
        }
    }

    var placement: (region: Region, h: HAlign)? {
        switch self {
        case .group(let group): return (group.region, group.h)
        case .stack(let stack): return (stack.region, stack.h)
        case .tile: return nil
        }
    }

    var textLineCount: Int { items.map(\.textLineCount).reduce(0, +) }

    func applying(_ options: RenderOptions, firstLineIndex: Int) -> Element {
        switch self {
        case .group(let group):
            var result = group
            result.items = Self.applying(options, to: group.items, firstLineIndex: firstLineIndex)
            return .group(result)
        case .stack(let stack):
            var nextLineIndex = firstLineIndex
            var result = stack
            result.rows = stack.rows.map { row in
                let adjusted = Self.applying(options, to: row, firstLineIndex: nextLineIndex)
                nextLineIndex += row.map(\.textLineCount).reduce(0, +)
                return adjusted
            }
            result.rowSpacing = stack.rowSpacing * options.textScale
            return .stack(result)
        case .tile(let tile):
            var scaled = tile
            scaled.size = tile.size * options.textScale
            scaled.weight = options.fontWeight ?? tile.weight
            scaled.color = options.textColor.map { Self.keepingAlpha(of: tile.color, rgbFrom: $0) } ?? tile.color
            return .tile(scaled)
        }
    }

    /// 对一行项目套用选项。行号按原始顺序编，和 `textLineSlots` 一致；隐藏 Logo 时连同分隔线一起去掉，不影响文字行编号。
    private static func applying(
        _ options: RenderOptions, to items: [GroupItem], firstLineIndex: Int
    ) -> [GroupItem] {
        let hasLogo = items.contains { if case .logo = $0 { return true } else { return false } }
        let shouldDropLogo = hasLogo && !options.isLogoVisible
        var nextLineIndex = firstLineIndex
        return items.compactMap { item -> GroupItem? in
            let lineIndex = nextLineIndex
            nextLineIndex += item.textLineCount
            switch item {
            case .logo, .divider: return shouldDropLogo ? nil : item.applying(options, firstLineIndex: lineIndex)
            case .text: return item.applying(options, firstLineIndex: lineIndex)
            }
        }
    }

    /// 平铺水印换色时保留原来的透明度，否则会变成不透明的满屏文字。
    private static func keepingAlpha(of original: String, rgbFrom replacement: String) -> String {
        let originalHex = original.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let replacementHex = replacement.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard originalHex.count == 8, replacementHex.count >= 6 else { return replacement }
        return "#" + replacementHex.prefix(6) + originalHex.suffix(2)
    }
}

extension GroupItem {
    var textLineCount: Int {
        if case .text(let lines, _, _) = self { return lines.count }
        return 0
    }

    func applying(_ options: RenderOptions, firstLineIndex: Int) -> GroupItem {
        let scale = options.textScale
        switch self {
        case .text(let lines, let align, let lineSpacing):
            let adjusted = lines.enumerated().map { offset, line in
                TextLine(
                    options.lineOverrides[firstLineIndex + offset] ?? line.text,
                    size: line.size * scale,
                    weight: options.fontWeight ?? line.weight,
                    color: options.textColor ?? line.color
                )
            }
            return .text(lines: adjusted, align: align, lineSpacing: lineSpacing * scale)
        case .logo(let height, let color):
            return .logo(height: height * scale, color: options.logoColor ?? options.textColor ?? color)
        case .divider(let height, let width, let color):
            return .divider(height: height * scale, width: width, color: color)
        }
    }
}
