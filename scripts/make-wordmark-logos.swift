// 生成内置的品牌字标 PNG（透明底、黑字）。它们只是品牌名文字，不是官方 Logo；
// 想用官方 Logo，把同名 PNG 放进 Sources/BorderMarkCore/Resources/Logos 或用户 Logo 文件夹即可。
// 用法：swift scripts/make-wordmark-logos.swift <输出目录>
import AppKit

// 只生成 Simple Icons 里没有的品牌；其余品牌的官方图标由 svg-to-logo.swift 从 Simple Icons 转换而来。
let brands = ["Canon", "HASSELBLAD", "OLYMPUS", "OM Digital", "PENTAX", "RICOH", "SIGMA"]
let height: CGFloat = 160
let padding: CGFloat = 8

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("用法：swift make-wordmark-logos.swift <输出目录>\n".utf8))
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

for brand in brands {
    let font = NSFont.systemFont(ofSize: height * 0.78, weight: .heavy)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        .kern: -height * 0.01,
    ]
    let label = brand == "OM Digital" ? "OM SYSTEM" : brand
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attributes))
    var ascent: CGFloat = 0, descent: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))

    guard let context = CGContext(
        data: nil, width: Int(ceil(width + padding * 2)), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    context.textPosition = CGPoint(x: padding, y: (height - (ascent + descent)) / 2 + descent)
    CTLineDraw(line, context)

    let url = directory.appendingPathComponent("\(brand).png")
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { continue }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    print(url.lastPathComponent)
}
