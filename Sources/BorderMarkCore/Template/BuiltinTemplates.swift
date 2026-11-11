import Foundation

/// 内置水印模式。每个都是普通的 `Template` 值，和用户 JSON 模板走同一个渲染器。
public enum BuiltinTemplates {
    public static let all: [Template] = designs.map(tuningBorder)

    /// 所有内置模式的边框在原始设计的基础上统一收窄到这个倍数。界面上"边框宽度 1.00×"对应的就是收窄后的结果。
    private static let borderTuning = 0.7
    private static let ratioPrecision = 10_000.0

    private static func tuningBorder(_ template: Template) -> Template {
        func tuned(_ value: Double) -> Double {
            // 四舍五入到万分位，避免导出的 JSON 里出现 0.13299999 这样的浮点尾数
            (value * borderTuning * ratioPrecision).rounded() / ratioPrecision
        }
        var result = template
        result.border = EdgeRatios(
            top: tuned(template.border.top), left: tuned(template.border.left),
            bottom: tuned(template.border.bottom), right: tuned(template.border.right)
        )
        return result
    }

    /// 原始设计稿的边框比例
    private static let designs: [Template] = [
        blurCard,
        classic(id: "classic-white", name: "经典白底", background: "#FFFFFF", primary: ink, secondary: gray),
        classic(id: "classic-black", name: "经典黑底", background: "#0B0B0C", primary: "#F5F5F5", secondary: "#8E8E93"),
        galleryFrame,
        polaroid,
        minimalLine,
        dominantCard,
        filmStrip,
        sidebar,
        gradientPoster,
        cornerOverlay,
        signature,
        tiled,
    ]

    private static let ink = "#111111"
    private static let gray = "#8A8A8E"
    private static let hairline = "#D0D0D4"
    private static let white = "#FFFFFF"
    private static let softWhite = "#FFFFFFCC"
    private static let detailSize = 0.025

    // MARK: - 底栏类

    private static func classic(
        id: String, name: String, background: String, primary: String, secondary: String
    ) -> Template {
        Template(
            id: id,
            name: name,
            summary: "下方信息栏：左镜头时间，右 Logo、相机名与参数",
            border: EdgeRatios(top: 0, left: 0, bottom: 0.13, right: 0),
            background: .solid(color: background),
            elements: [
                .group(GroupElement(region: .bottom, h: .leading, insetX: 0.045, items: [
                    .text(lines: [
                        TextLine("{Lens}", size: 0.032, color: primary),
                        TextLine("{DateTime}", size: 0.021, color: secondary),
                    ], align: .leading, lineSpacing: 0.008),
                ])),
                .group(GroupElement(region: .bottom, h: .trailing, insetX: 0.045, spacing: 0.022, items: [
                    .logo(height: 0.042, color: primary),
                    .divider(height: 0.05, width: 0.0018, color: secondary),
                    // 副标题（完整相机名）和下面的参数用同一套字体
                    .text(lines: [
                        TextLine("{Camera}", size: detailSize, color: primary),
                        TextLine("{Params}", size: detailSize, color: primary),
                    ], align: .leading, lineSpacing: 0.008),
                ])),
            ]
        )
    }

    private static let galleryFrame = Template(
        id: "gallery-frame",
        name: "画廊白框",
        summary: "四周留白，底部 Logo 加相机名，下方参数",
        border: EdgeRatios(all: 0.05, bottom: 0.17),
        background: .solid(color: white),
        elements: [
            .stack(StackElement(region: .bottom, spacing: 0.018, rowSpacing: 0.016, rows: [
                [
                    .logo(height: 0.034, color: ink),
                    .text(lines: [TextLine("{Model}", size: 0.032, color: ink)], align: .leading, lineSpacing: 0),
                ],
                [
                    .text(lines: [TextLine("{Params}", size: 0.023, color: gray)], align: .center, lineSpacing: 0),
                ],
            ])),
        ]
    )

    private static let polaroid = Template(
        id: "polaroid",
        name: "拍立得",
        summary: "厚底边相纸，可写一句话",
        border: EdgeRatios(all: 0.06, bottom: 0.26),
        background: .solid(color: "#FAF8F3"),
        photo: PhotoStyle(cornerRadius: 0.004),
        fontName: "Georgia",
        elements: [
            .group(GroupElement(region: .bottom, items: [
                .text(lines: [
                    TextLine("{Custom}", size: 0.05, color: "#2B2B2B"),
                    TextLine("{Model}  ·  {Date}", size: 0.024, color: "#9A958C"),
                ], align: .center, lineSpacing: 0.02),
            ])),
        ]
    )

    private static let minimalLine = Template(
        id: "minimal-line",
        name: "极简单行",
        summary: "细白边，一行小字",
        border: EdgeRatios(all: 0.03, bottom: 0.085),
        background: .solid(color: white),
        elements: [
            .group(GroupElement(region: .bottom, items: [
                .text(lines: [
                    TextLine("{Model}  ·  {Params}", size: 0.02, weight: .medium, color: gray),
                ], align: .center, lineSpacing: 0),
            ])),
        ]
    )

    // MARK: - 卡片类

    private static let cardElements: [Element] = [
        // 第一行：Logo + 相机名；第二行：拍摄参数
        .stack(StackElement(region: .bottom, spacing: 0.018, rowSpacing: 0.016, rows: [
            [
                .logo(height: 0.034, color: white),
                .text(lines: [TextLine("{Model}", size: 0.032, color: white)], align: .leading, lineSpacing: 0),
            ],
            [
                .text(lines: [TextLine("{Params}", size: 0.023, color: softWhite)], align: .center, lineSpacing: 0),
            ],
        ])),
    ]

    private static let blurCard = Template(
        id: "blur-card",
        name: "毛玻璃卡片",
        summary: "照片模糊做背景，圆角加阴影，底部 Logo 加相机名，下方参数",
        border: EdgeRatios(all: 0.09, bottom: 0.19),
        background: .blur(radius: 0.09, dim: 0.22),
        photo: PhotoStyle(cornerRadius: 0.03, shadow: .standard),
        elements: cardElements
    )

    private static let dominantCard = Template(
        id: "dominant-card",
        name: "主色卡片",
        summary: "取照片平均色做背景，底部 Logo 加相机名，下方参数",
        border: EdgeRatios(all: 0.09, bottom: 0.19),
        background: .dominant(dim: 0.25),
        photo: PhotoStyle(cornerRadius: 0.03, shadow: .standard),
        elements: cardElements
    )

    private static let gradientPoster = Template(
        id: "gradient-poster",
        name: "渐变海报",
        summary: "深色渐变底，顶部品牌，底部参数",
        border: EdgeRatios(top: 0.14, left: 0.07, bottom: 0.2, right: 0.07),
        background: .gradient(from: "#1B1F2A", to: "#3A2A45"),
        photo: PhotoStyle(cornerRadius: 0.012, shadow: .standard),
        elements: [
            .group(GroupElement(region: .top, items: [.logo(height: 0.05, color: white)])),
            .group(GroupElement(region: .bottom, items: [
                .text(lines: [
                    TextLine("{Params}", size: 0.03, weight: .semibold, color: white),
                    TextLine("{Lens}", size: 0.021, color: softWhite),
                    TextLine("{DateTime}", size: 0.019, color: "#FFFFFF80"),
                ], align: .center, lineSpacing: 0.011),
            ])),
        ]
    )

    // MARK: - 胶片 / 侧栏

    private static let filmAmber = "#FF9F0A"

    private static let filmStrip = Template(
        id: "film-strip",
        name: "胶片黑边",
        summary: "上下黑边，琥珀色等宽字",
        border: EdgeRatios(top: 0.085, left: 0.035, bottom: 0.085, right: 0.035),
        background: .solid(color: "#0A0A0A"),
        fontName: "Menlo",
        elements: [
            .group(GroupElement(region: .top, h: .leading, insetX: 0.04, items: [
                .text(lines: [TextLine("{Model}", size: 0.02, weight: .bold, color: filmAmber)],
                      align: .leading, lineSpacing: 0),
            ])),
            .group(GroupElement(region: .top, h: .trailing, insetX: 0.04, items: [
                .text(lines: [TextLine("{Lens}", size: 0.018, color: filmAmber)], align: .trailing, lineSpacing: 0),
            ])),
            .group(GroupElement(region: .bottom, h: .leading, insetX: 0.04, items: [
                .text(lines: [TextLine("{DateTime}", size: 0.02, color: filmAmber)], align: .leading, lineSpacing: 0),
            ])),
            .group(GroupElement(region: .bottom, h: .trailing, insetX: 0.04, items: [
                .text(lines: [TextLine("{Params}", size: 0.02, weight: .bold, color: filmAmber)],
                      align: .trailing, lineSpacing: 0),
            ])),
        ]
    )

    private static let sidebar = Template(
        id: "sidebar",
        name: "右侧参数栏",
        summary: "参数竖排在右侧白栏",
        border: EdgeRatios(top: 0, left: 0, bottom: 0, right: 0.24),
        background: .solid(color: white),
        elements: [
            .group(GroupElement(region: .right, v: .center, items: [
                .text(lines: [
                    TextLine("{Model}", size: 0.024, weight: .bold, color: ink),
                    TextLine("{FocalLength}", size: 0.03, weight: .light, color: ink),
                    TextLine("{FNumber}", size: 0.03, weight: .light, color: ink),
                    TextLine("{Shutter}", size: 0.03, weight: .light, color: ink),
                    TextLine("{ISO}", size: 0.03, weight: .light, color: ink),
                    TextLine("{Date}", size: 0.018, color: gray),
                ], align: .center, lineSpacing: 0.022),
            ])),
        ]
    )

    // MARK: - 无边框叠加类

    private static let cornerOverlay = Template(
        id: "corner-overlay",
        name: "角标水印",
        summary: "无边框，左下角叠加机型参数",
        elements: [
            .group(GroupElement(region: .photo, h: .leading, v: .bottom, insetX: 0.035, insetY: 0.035, items: [
                .text(lines: [
                    TextLine("{Model}", size: 0.028, weight: .semibold, color: white),
                    TextLine("{Params}", size: 0.02, color: softWhite),
                ], align: .leading, lineSpacing: 0.007),
            ])),
        ]
    )

    private static let signature = Template(
        id: "signature",
        name: "署名水印",
        summary: "无边框，右下角版权署名",
        elements: [
            .group(GroupElement(region: .photo, h: .trailing, v: .bottom, insetX: 0.035, insetY: 0.035, items: [
                .text(lines: [
                    TextLine("{Copyright}", size: 0.026, weight: .medium, color: white),
                    TextLine("{Custom}", size: 0.018, color: softWhite),
                ], align: .trailing, lineSpacing: 0.006),
            ])),
        ]
    )

    private static let tiled = Template(
        id: "tiled",
        name: "防盗平铺",
        summary: "半透明文字斜向铺满全图",
        elements: [
            .tile(TileElement(text: "{Copyright} {Custom}")),
        ]
    )
}
