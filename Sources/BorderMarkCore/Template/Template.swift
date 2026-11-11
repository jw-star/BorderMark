import Foundation

// 模板里所有长度都是"相对照片短边的比例"，这样预览和原图导出的版式完全一致。

/// 一个水印模式：边框 + 背景 + 照片样式 + 若干元素。可直接与 JSON 互转。
public struct Template: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var border: EdgeRatios
    public var background: Background
    public var photo: PhotoStyle
    /// 字体族名；`nil` 表示系统字体。
    public var fontName: String?
    public var elements: [Element]

    public init(
        id: String,
        name: String,
        summary: String = "",
        border: EdgeRatios = .zero,
        background: Background = .solid(color: "#FFFFFF"),
        photo: PhotoStyle = PhotoStyle(),
        fontName: String? = nil,
        elements: [Element] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.border = border
        self.background = background
        self.photo = photo
        self.fontName = fontName
        self.elements = elements
    }
}

public struct EdgeRatios: Codable, Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public static let zero = EdgeRatios(top: 0, left: 0, bottom: 0, right: 0)

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public init(all: Double, bottom: Double? = nil) {
        self.init(top: all, left: all, bottom: bottom ?? all, right: all)
    }

    public func scaled(by factor: Double) -> EdgeRatios {
        EdgeRatios(top: top * factor, left: left * factor, bottom: bottom * factor, right: right * factor)
    }
}

public enum Background: Codable, Equatable, Sendable {
    /// 纯色，`#RRGGBB` 或 `#RRGGBBAA`
    case solid(color: String)
    /// 自上而下的线性渐变
    case gradient(from: String, to: String)
    /// 照片自身放大模糊做背景；`dim` 为压暗程度 0–1
    case blur(radius: Double, dim: Double)
    /// 照片平均色做背景
    case dominant(dim: Double)
}

public struct PhotoStyle: Codable, Equatable, Sendable {
    public var cornerRadius: Double
    public var shadow: ShadowStyle?

    public init(cornerRadius: Double = 0, shadow: ShadowStyle? = nil) {
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }
}

public struct ShadowStyle: Codable, Equatable, Sendable {
    public var radius: Double
    public var offsetY: Double
    public var opacity: Double

    public static let standard = ShadowStyle(radius: 0.03, offsetY: 0.012, opacity: 0.35)

    public init(radius: Double, offsetY: Double, opacity: Double) {
        self.radius = radius
        self.offsetY = offsetY
        self.opacity = opacity
    }
}

public enum HAlign: String, Codable, Sendable { case leading, center, trailing }
public enum VAlign: String, Codable, Sendable { case top, center, bottom }
public enum FontWeight: String, Codable, Sendable { case light, regular, medium, semibold, bold }

/// 元素摆放的参照区域。`top/bottom/left/right` 指对应那条边框带。
public enum Region: String, Codable, Sendable { case canvas, photo, top, bottom, left, right }

public enum Element: Codable, Equatable, Sendable {
    /// 一组横向排列的文字 / Logo / 分隔线，锚定在某个区域的九宫格位置
    case group(GroupElement)
    /// 多行上下堆叠，每一行是一组横向排列的文字 / Logo / 分隔线
    case stack(StackElement)
    /// 斜向平铺的文字水印
    case tile(TileElement)

    private enum CodingKeys: String, CodingKey { case group, stack, tile }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let group = try container.decodeIfPresent(GroupElement.self, forKey: .group) {
            self = .group(group)
        } else if let stack = try container.decodeIfPresent(StackElement.self, forKey: .stack) {
            self = .stack(stack)
        } else if let tile = try container.decodeIfPresent(TileElement.self, forKey: .tile) {
            self = .tile(tile)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "元素必须包含 group、stack 或 tile")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .group(let group): try container.encode(group, forKey: .group)
        case .stack(let stack): try container.encode(stack, forKey: .stack)
        case .tile(let tile): try container.encode(tile, forKey: .tile)
        }
    }
}

public struct GroupElement: Codable, Equatable, Sendable {
    public var region: Region
    public var h: HAlign
    public var v: VAlign
    public var insetX: Double
    public var insetY: Double
    public var spacing: Double
    public var items: [GroupItem]

    public init(
        region: Region,
        h: HAlign = .center,
        v: VAlign = .center,
        insetX: Double = 0,
        insetY: Double = 0,
        spacing: Double = 0.02,
        items: [GroupItem]
    ) {
        self.region = region
        self.h = h
        self.v = v
        self.insetX = insetX
        self.insetY = insetY
        self.spacing = spacing
        self.items = items
    }
}

/// 上下堆叠的多行。整体锚定在区域的九宫格位置，行与行之间按 `h` 对齐。
public struct StackElement: Codable, Equatable, Sendable {
    public var region: Region
    public var h: HAlign
    public var v: VAlign
    public var insetX: Double
    public var insetY: Double
    /// 同一行里各项之间的间距
    public var spacing: Double
    /// 行与行之间的间距
    public var rowSpacing: Double
    public var rows: [[GroupItem]]

    public init(
        region: Region,
        h: HAlign = .center,
        v: VAlign = .center,
        insetX: Double = 0,
        insetY: Double = 0,
        spacing: Double = 0.02,
        rowSpacing: Double = 0.012,
        rows: [[GroupItem]]
    ) {
        self.region = region
        self.h = h
        self.v = v
        self.insetX = insetX
        self.insetY = insetY
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.rows = rows
    }
}

public enum GroupItem: Codable, Equatable, Sendable {
    /// 多行文字块
    case text(lines: [TextLine], align: HAlign, lineSpacing: Double)
    /// 品牌 Logo：用户提供了图片就画图片，否则用品牌名文字代替
    case logo(height: Double, color: String)
    /// 竖直分隔线
    case divider(height: Double, width: Double, color: String)
}

public struct TextLine: Codable, Equatable, Sendable {
    /// 可含占位符，如 `{Model}`、`{Params}`
    public var text: String
    public var size: Double
    public var weight: FontWeight
    public var color: String

    public init(_ text: String, size: Double, weight: FontWeight = .regular, color: String) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
    }
}

public struct TileElement: Codable, Equatable, Sendable {
    public var region: Region
    public var text: String
    public var size: Double
    public var weight: FontWeight
    public var color: String
    /// 逆时针角度
    public var angle: Double
    public var spacingX: Double
    public var spacingY: Double

    public init(
        region: Region = .photo,
        text: String,
        size: Double = 0.03,
        weight: FontWeight = .medium,
        color: String = "#FFFFFF40",
        angle: Double = 30,
        spacingX: Double = 0.12,
        spacingY: Double = 0.16
    ) {
        self.region = region
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.angle = angle
        self.spacingX = spacingX
        self.spacingY = spacingY
    }
}
