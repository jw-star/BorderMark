import CoreGraphics
import Foundation

public enum HexColor {
    public struct RGBA: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double
    }

    /// 解析 `#RGB`、`#RRGGBB`、`#RRGGBBAA`（`#` 可省略）。格式不对返回 `nil`。
    public static func parse(_ string: String) -> RGBA? {
        let raw = string.trimmingCharacters(in: .whitespaces)
        let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        let expanded = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard expanded.count == 6 || expanded.count == 8, let value = UInt64(expanded, radix: 16) else { return nil }

        let hasAlpha = expanded.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        return RGBA(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    public static func string(red: Double, green: Double, blue: Double, alpha: Double = 1) -> String {
        let components = [red, green, blue].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        let rgb = components.map { String(format: "%02X", $0) }.joined()
        guard alpha < 1 else { return "#\(rgb)" }
        return "#\(rgb)" + String(format: "%02X", Int((max(alpha, 0) * 255).rounded()))
    }

    /// 无法解析时退回不透明黑色，保证渲染不中断。
    static func cgColor(_ string: String) -> CGColor {
        let rgba = parse(string) ?? RGBA(red: 0, green: 0, blue: 0, alpha: 1)
        return CGColor(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }
}
