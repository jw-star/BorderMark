import AppKit
import BorderMarkCore
import SwiftUI

extension Color {
    init(hex: String) {
        let rgba = HexColor.parse(hex)
        self.init(
            .sRGB,
            red: rgba?.red ?? 0,
            green: rgba?.green ?? 0,
            blue: rgba?.blue ?? 0,
            opacity: rgba?.alpha ?? 1
        )
    }

    /// 转成模板使用的 `#RRGGBB`（带透明度时为 `#RRGGBBAA`）。
    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        return HexColor.string(
            red: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: color.alphaComponent
        )
    }
}

/// 把"十六进制字符串"绑定适配成 ColorPicker 需要的 `Color` 绑定。
func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
    Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = $0.hexString })
}
