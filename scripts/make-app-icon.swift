// 绘制 App 图标（1024×1024 PNG）。图案：石墨黑圆角底上，一张略微倾斜、带白边和水印栏的日落照片。
// 用法：swift scripts/make-app-icon.swift <输出.png>
import AppKit

let side: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

guard CommandLine.arguments.count == 2,
      let context = CGContext(
          data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else {
    FileHandle.standardError.write(Data("用法：swift make-app-icon.swift <输出.png>\n".utf8))
    exit(1)
}

// MARK: 底板（macOS 图标规范：824pt 圆角方块居中，四周留出投影空间）
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let platePath = rounded(plate, 186)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, alpha: 0.32))
context.addPath(platePath)
context.setFillColor(color(0x121214))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(platePath)
context.clip()
context.drawLinearGradient(
    gradient([color(0x3A3A3F), color(0x1B1B1E), color(0x050506)]),
    start: CGPoint(x: plate.minX, y: plate.maxY), end: CGPoint(x: plate.maxX, y: plate.minY), options: []
)
// 左上角一点柔和的高光，让黑色有材质感而不是一块死黑
context.drawRadialGradient(
    gradient([color(0xFFFFFF, alpha: 0.13), color(0xFFFFFF, alpha: 0)]),
    startCenter: CGPoint(x: 250, y: 830), startRadius: 0,
    endCenter: CGPoint(x: 250, y: 830), endRadius: 560, options: []
)
context.restoreGState()

// 顶部一圈细亮边，模拟金属倒角
context.saveGState()
context.addPath(rounded(plate.insetBy(dx: 2, dy: 2), 184))
context.setStrokeColor(color(0xFFFFFF, alpha: 0.1))
context.setLineWidth(4)
context.strokePath()
context.restoreGState()

// MARK: 照片卡片（整体逆时针倾斜一点）
context.saveGState()
context.translateBy(x: side / 2, y: side / 2)
context.rotate(by: 5 * .pi / 180)
context.translateBy(x: -side / 2, y: -side / 2)

let card = CGRect(x: 226, y: 204, width: 572, height: 616)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -22), blur: 46, color: color(0x000000, alpha: 0.6))
context.addPath(rounded(card, 40))
context.setFillColor(color(0xFCFCFD))
context.fillPath()
context.restoreGState()

// 照片
let barHeight: CGFloat = 148
let inset: CGFloat = 34
let photo = CGRect(
    x: card.minX + inset, y: card.minY + barHeight,
    width: card.width - inset * 2, height: card.height - barHeight - inset
)
context.saveGState()
context.addPath(rounded(photo, 18))
context.clip()
context.drawLinearGradient(
    gradient([color(0x4E539F), color(0xB67F8C), color(0xF7A45C)]),
    start: CGPoint(x: photo.midX, y: photo.maxY), end: CGPoint(x: photo.midX, y: photo.minY + photo.height * 0.28),
    options: [.drawsAfterEndLocation]
)
context.setFillColor(color(0xFFE9B8))
context.fillEllipse(in: CGRect(x: photo.minX + photo.width * 0.6, y: photo.minY + photo.height * 0.44, width: 108, height: 108))

let ridges: [(base: CGFloat, amplitude: CGFloat, phase: CGFloat, fill: UInt32)] = [
    (0.40, 0.085, 0.4, 0x6C5682), (0.27, 0.075, 2.3, 0x41395F), (0.13, 0.06, 4.1, 0x1A1A2E),
]
for ridge in ridges {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: photo.minX, y: photo.minY))
    for step in 0...80 {
        let t = CGFloat(step) / 80
        let wave = sin(t * 7.5 + ridge.phase) * 0.65 + sin(t * 17 + ridge.phase * 2) * 0.35
        path.addLine(to: CGPoint(
            x: photo.minX + t * photo.width,
            y: photo.minY + photo.height * (ridge.base + ridge.amplitude * wave)
        ))
    }
    path.addLine(to: CGPoint(x: photo.maxX, y: photo.minY))
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(color(ridge.fill))
    context.fillPath()
}
context.restoreGState()

// 水印栏：品牌标记 + 分隔线 + 两行文字
let barMidY = card.minY + barHeight / 2
let mark = CGRect(x: photo.minX + 6, y: barMidY - 30, width: 60, height: 60)
context.addPath(rounded(mark, 17))
context.setFillColor(color(0x121214))
context.fillPath()
context.setFillColor(color(0xFF6B3D))
context.fillEllipse(in: mark.insetBy(dx: 19, dy: 19))

context.setFillColor(color(0xD3D4DC))
context.fill(CGRect(x: mark.maxX + 22, y: barMidY - 30, width: 4, height: 60))

let textX = mark.maxX + 48
context.addPath(rounded(CGRect(x: textX, y: barMidY + 5, width: 250, height: 20), 10))
context.setFillColor(color(0x1A1A1D))
context.fillPath()
context.addPath(rounded(CGRect(x: textX, y: barMidY - 25, width: 170, height: 15), 7.5))
context.setFillColor(color(0xA9ABB8))
context.fillPath()

context.restoreGState()

// MARK: 输出
let output = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
exit(CGImageDestinationFinalize(destination) ? 0 : 1)
