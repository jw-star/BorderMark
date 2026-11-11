import Foundation

/// 相机 / 手机品牌的规范写法。EXIF 里的厂商字段五花八门（"NIKON CORPORATION"、"OLYMPUS IMAGING CORP."），
/// 这里按第一个词归一成品牌自己惯用的大小写。
public enum BrandNames {
    private static let displayNames: [String: String] = [
        "apple": "Apple", "canon": "Canon", "dji": "DJI", "fujifilm": "FUJIFILM", "google": "Google",
        "hasselblad": "Hasselblad", "huawei": "HUAWEI", "leica": "Leica", "nikon": "Nikon",
        "olympus": "OLYMPUS", "om": "OM SYSTEM", "oppo": "OPPO", "panasonic": "Panasonic",
        "pentax": "PENTAX", "ricoh": "RICOH", "samsung": "SAMSUNG", "sigma": "SIGMA", "sony": "SONY",
        "vivo": "vivo", "xiaomi": "Xiaomi",
    ]

    /// 不认识的品牌原样返回第一个词；没有厂商信息返回空串。
    public static func displayName(forMake make: String) -> String {
        guard let first = make.split(separator: " ").first else { return "" }
        return displayNames[first.lowercased()] ?? String(first)
    }
}
