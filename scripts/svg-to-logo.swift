// 把单色 SVG 图标转成透明底 PNG，并裁掉四周的透明留白。
// 用法：swift scripts/svg-to-logo.swift <输入.svg> <输出.png>
import AppKit

let renderSide = 2048
let outputHeight = 240

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else { fail("用法：swift svg-to-logo.swift <输入.svg> <输出.png>") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])

guard let svg = NSImage(contentsOf: input) else { fail("无法读取 \(input.lastPathComponent)") }
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let canvas = CGContext(
    data: nil, width: renderSide, height: renderSide, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fail("无法创建画布") }

NSGraphicsContext.current = NSGraphicsContext(cgContext: canvas, flipped: false)
svg.draw(in: CGRect(x: 0, y: 0, width: renderSide, height: renderSide))
NSGraphicsContext.current = nil

// 找出不透明像素的包围盒
guard let data = canvas.data else { fail("画布没有像素数据") }
let bytes = data.bindMemory(to: UInt8.self, capacity: canvas.bytesPerRow * renderSide)
var minX = renderSide, minY = renderSide, maxX = -1, maxY = -1
for y in 0..<renderSide {
    for x in 0..<renderSide where bytes[y * canvas.bytesPerRow + x * 4 + 3] > 8 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= minX, maxY >= minY, let full = canvas.makeImage(),
      let cropped = full.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
else { fail("\(input.lastPathComponent) 渲染出来是空的") }

let scale = CGFloat(outputHeight) / CGFloat(cropped.height)
let width = max(1, Int((CGFloat(cropped.width) * scale).rounded()))
guard let target = CGContext(
    data: nil, width: width, height: outputHeight, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fail("无法创建输出画布") }
target.interpolationQuality = .high
target.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: outputHeight))

guard let image = target.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)
else { fail("无法写出 \(output.lastPathComponent)") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("无法写出 \(output.lastPathComponent)") }
print("\(output.lastPathComponent) \(width)x\(outputHeight)")
