import Foundation

/// 把模板文字里的 `{Model}`、`{Params}` 等占位符替换成照片的实际信息。
///
/// 规则：
/// - 缺失的字段替换为空串，之后合并多余空格、去掉首尾悬空的分隔符（`·`、`|`）。
/// - 一行里有占位符但全部为空时，整行返回 `nil`（由渲染器丢弃）。
public struct PlaceholderResolver: Sendable {
    public static let supportedKeys = [
        "Make", "Model", "Camera", "Lens", "FocalLength", "FocalLength35", "FNumber", "Shutter", "ISO",
        "Params", "Date", "Time", "DateTime", "GPS", "Author", "Copyright", "Custom",
    ]

    private static let paramsSeparator = "  "
    private static let danglingCharacters = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "·|"))

    public let values: [String: String]

    public init(metadata: PhotoMetadata, options: RenderOptions = RenderOptions()) {
        let base = Self.baseValues(metadata: metadata, options: options)
        let overrides = options.fieldOverrides.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        let merged = base.merging(overrides) { _, override in override }
        self.values = Self.withComputed(merged)
    }

    public func resolve(_ text: String) -> String? {
        var output = ""
        var placeholderCount = 0
        var filledCount = 0
        var remainder = Substring(text)

        while let open = remainder.firstIndex(of: "{"),
              let close = remainder[open...].firstIndex(of: "}") {
            output += remainder[..<open]
            let key = String(remainder[remainder.index(after: open)..<close])
            let value = values[key] ?? ""
            placeholderCount += 1
            if !value.isEmpty { filledCount += 1 }
            output += value
            remainder = remainder[remainder.index(after: close)...]
        }
        output += remainder

        if placeholderCount > 0 && filledCount == 0 { return nil }
        let tidy = Self.tidied(output)
        return tidy.isEmpty ? nil : tidy
    }

    // MARK: - Formatting

    private static func baseValues(metadata: PhotoMetadata, options: RenderOptions) -> [String: String] {
        let author = options.author.trimmingCharacters(in: .whitespaces)
        return [
            "Make": metadata.make ?? "",
            "Model": metadata.model ?? "",
            "Lens": metadata.lens ?? "",
            "FocalLength": metadata.focalLength.map { "\(trimmedNumber($0))mm" } ?? "",
            "FocalLength35": metadata.focalLength35.map { "\(trimmedNumber($0))mm" } ?? "",
            "FNumber": metadata.fNumber.map { "f/\(trimmedNumber($0))" } ?? "",
            "Shutter": metadata.exposureTime.map(shutterText) ?? "",
            "ISO": metadata.iso.map { "ISO\($0)" } ?? "",
            "Date": metadata.date.map { formatted($0, "yyyy.MM.dd") } ?? "",
            "Time": metadata.date.map { formatted($0, "HH:mm") } ?? "",
            "DateTime": metadata.date.map { formatted($0, "yyyy.MM.dd HH:mm") } ?? "",
            "GPS": gpsText(latitude: metadata.latitude, longitude: metadata.longitude),
            "Author": author,
            "Copyright": author.isEmpty ? "" : "© \(author)",
            "Custom": options.customText.trimmingCharacters(in: .whitespaces),
        ]
    }

    /// `Params` 和 `Camera` 由其他字段拼成，放在覆盖值合并之后计算，这样手动改 ISO 或机型也会反映进来。
    private static func withComputed(_ values: [String: String]) -> [String: String] {
        let parts = ["FocalLength", "FNumber", "Shutter", "ISO"].compactMap { values[$0] }.filter { !$0.isEmpty }
        let computed = [
            "Params": parts.joined(separator: paramsSeparator),
            "Camera": cameraName(make: values["Make"] ?? "", model: values["Model"] ?? ""),
        ]
        return values.merging(computed) { existing, new in existing.isEmpty ? new : existing }
    }

    /// 完整相机名：品牌 + 型号，品牌用规范写法且不重复。
    /// ("NIKON CORPORATION", "NIKON Z5_2") → "Nikon Z5_2"；("SONY", "ILCE-7M4") → "SONY ILCE-7M4"
    static func cameraName(make: String, model: String) -> String {
        let brand = BrandNames.displayName(forMake: make)
        guard !model.isEmpty else { return brand }
        guard !brand.isEmpty else { return model }

        let makeWord = make.split(separator: " ").first.map(String.init) ?? ""
        let rest = model.dropFirst(makeWord.count)
        let startsWithBrand = model.lowercased().hasPrefix(makeWord.lowercased())
            && (rest.first.map { !$0.isLetter } ?? true)
        return startsWithBrand ? brand + rest : "\(brand) \(model)"
    }

    static func shutterText(_ seconds: Double) -> String {
        if seconds >= 1 { return "\(trimmedNumber(seconds))s" }
        return "1/\(Int((1 / seconds).rounded()))s"
    }

    static func trimmedNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private static func gpsText(latitude: Double?, longitude: Double?) -> String {
        guard let latitude, let longitude else { return "" }
        return "\(dms(latitude, positive: "N", negative: "S")) \(dms(longitude, positive: "E", negative: "W"))"
    }

    private static func dms(_ value: Double, positive: String, negative: String) -> String {
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutes = Int(((absolute - Double(degrees)) * 60).rounded(.down))
        return "\(degrees)°\(minutes)'\(value >= 0 ? positive : negative)"
    }

    private static func tidied(_ text: String) -> String {
        let collapsed = text.split(separator: " ", omittingEmptySubsequences: false)
            .reduce(into: [Substring]()) { parts, part in
                // 保留至多两个连续空格，模板常用双空格分隔参数
                if part.isEmpty, parts.suffix(1).allSatisfy(\.isEmpty), !parts.isEmpty { return }
                parts.append(part)
            }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: danglingCharacters)
    }
}
