import Foundation

/// 加载模板：内置模板 + 用户目录下的 `*.json`。同 id 的用户模板覆盖内置模板。
public enum TemplateStore {
    public struct LoadResult: Equatable, Sendable {
        public let templates: [Template]
        /// 加载失败的文件及原因，供界面提示
        public let problems: [String]
    }

    private static let maxBorderRatio = 3.0

    public static var userDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("BorderMark/Templates", isDirectory: true)
    }

    public static func load(from directory: URL = userDirectory) -> LoadResult {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var custom: [Template] = []
        var problems: [String] = []
        for file in jsonFiles {
            do {
                custom.append(try decode(Data(contentsOf: file), fileName: file.lastPathComponent))
            } catch {
                problems.append(error.localizedDescription)
            }
        }
        return LoadResult(templates: merged(builtin: BuiltinTemplates.all, custom: custom), problems: problems)
    }

    public static func decode(_ data: Data, fileName: String) throws -> Template {
        let template: Template
        do {
            template = try JSONDecoder().decode(Template.self, from: data)
        } catch {
            throw BorderMarkError.invalidTemplate(file: fileName, reason: "JSON 格式不正确（\(describe(error))）")
        }
        try validate(template, fileName: fileName)
        return template
    }

    public static func encode(_ template: Template) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(template)
    }

    /// 把内置模板写成 JSON 文件，方便用户照着改。已存在的同名文件不覆盖。返回新写入的文件数。
    @discardableResult
    public static func exportBuiltins(to directory: URL = userDirectory) throws -> Int {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        for template in BuiltinTemplates.all {
            let file = directory.appendingPathComponent("\(template.id).json")
            guard !FileManager.default.fileExists(atPath: file.path) else { continue }
            try encode(template).write(to: file, options: .atomic)
            written += 1
        }
        return written
    }

    static func merged(builtin: [Template], custom: [Template]) -> [Template] {
        let customByID = Dictionary(custom.map { ($0.id, $0) }) { _, later in later }
        let builtinIDs = Set(builtin.map(\.id))
        let replaced = builtin.map { customByID[$0.id] ?? $0 }
        let added = custom.filter { !builtinIDs.contains($0.id) && customByID[$0.id] == $0 }
        return replaced + added
    }

    private static func validate(_ template: Template, fileName: String) throws {
        func fail(_ reason: String) -> BorderMarkError { .invalidTemplate(file: fileName, reason: reason) }

        guard !template.id.trimmingCharacters(in: .whitespaces).isEmpty else { throw fail("id 不能为空") }
        guard !template.name.trimmingCharacters(in: .whitespaces).isEmpty else { throw fail("name 不能为空") }
        let edges = [template.border.top, template.border.left, template.border.bottom, template.border.right]
        guard edges.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= maxBorderRatio }) else {
            throw fail("border 各边必须在 0 到 \(Int(maxBorderRatio)) 之间")
        }
        for color in colors(in: template) where HexColor.parse(color) == nil {
            throw fail("颜色 \(color) 不是有效的十六进制色值")
        }
    }

    private static func colors(in template: Template) -> [String] {
        let backgroundColors: [String]
        switch template.background {
        case .solid(let color): backgroundColors = [color]
        case .gradient(let from, let to): backgroundColors = [from, to]
        case .blur, .dominant: backgroundColors = []
        }
        let elementColors = template.elements.flatMap { element -> [String] in
            if case .tile(let tile) = element { return [tile.color] }
            return element.items.flatMap { item -> [String] in
                switch item {
                case .text(let lines, _, _): return lines.map(\.color)
                case .logo(_, let color), .divider(_, _, let color): return [color]
                }
            }
        }
        return backgroundColors + elementColors
    }

    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, _): return "缺少字段 \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "字段 \(path) 有误"
        @unknown default: return error.localizedDescription
        }
    }
}
