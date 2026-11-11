import BorderMarkCore
import Foundation

// 命令行入口：批量加水印、列出模板、导出模板 JSON。输出走 stdout 是命令行工具的本职。

let usageText = """
用法：
  bordermark-cli list
  bordermark-cli render <图片...> [--template <id>] [--all] [--out <目录>]
                 [--format jpeg|heic|png] [--quality 0-1] [--max <长边像素>]
                 [--author <署名>] [--custom <文字>] [--logo <图片>]
  bordermark-cli logos
  bordermark-cli export-templates [目录]
  bordermark-cli sample <输出.jpg>
"""

struct RenderArguments {
    var inputs: [URL] = []
    var templateIDs: [String] = []
    var isAllTemplates = false
    var outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var format = ExportFormat.jpeg
    var quality = 1.0
    var maxPixelSize: Int?
    var logoURL: URL?
    var options = RenderOptions()
}

enum CLIError: LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message): return "\(message)\n\n\(usageText)"
        }
    }
}

func parseRenderArguments(_ arguments: [String]) throws -> RenderArguments {
    var parsed = RenderArguments()
    var index = 0

    func value(for flag: String) throws -> String {
        index += 1
        guard index < arguments.count else { throw CLIError.usage("\(flag) 后面缺少值") }
        return arguments[index]
    }

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--template": parsed.templateIDs.append(try value(for: argument))
        case "--all": parsed.isAllTemplates = true
        case "--out": parsed.outputDirectory = URL(fileURLWithPath: try value(for: argument), isDirectory: true)
        case "--author": parsed.options.author = try value(for: argument)
        case "--custom": parsed.options.customText = try value(for: argument)
        case "--logo": parsed.logoURL = URL(fileURLWithPath: try value(for: argument))
        case "--format":
            let raw = try value(for: argument)
            guard let format = ExportFormat(rawValue: raw.lowercased()) else {
                throw CLIError.usage("不支持的格式：\(raw)")
            }
            parsed.format = format
        case "--quality":
            guard let quality = Double(try value(for: argument)), (0...1).contains(quality) else {
                throw CLIError.usage("--quality 必须是 0 到 1 之间的数")
            }
            parsed.quality = quality
        case "--max":
            guard let size = Int(try value(for: argument)), size > 0 else {
                throw CLIError.usage("--max 必须是正整数")
            }
            parsed.maxPixelSize = size
        default:
            guard !argument.hasPrefix("--") else { throw CLIError.usage("未知选项：\(argument)") }
            parsed.inputs.append(URL(fileURLWithPath: argument))
        }
        index += 1
    }

    guard !parsed.inputs.isEmpty else { throw CLIError.usage("请至少指定一张图片") }
    return parsed
}

func selectedTemplates(_ arguments: RenderArguments) throws -> [Template] {
    let loaded = TemplateStore.load()
    loaded.problems.forEach { FileHandle.standardError.write(Data("警告：\($0)\n".utf8)) }
    if arguments.isAllTemplates { return loaded.templates }

    let ids = arguments.templateIDs.isEmpty ? ["classic-white"] : arguments.templateIDs
    return try ids.map { id in
        guard let template = loaded.templates.first(where: { $0.id == id }) else {
            throw CLIError.usage("找不到模板：\(id)（用 list 查看全部）")
        }
        return template
    }
}

func runRender(_ rawArguments: [String]) throws {
    let arguments = try parseRenderArguments(rawArguments)
    let templates = try selectedTemplates(arguments)
    let fixedLogo = try arguments.logoURL.map { try ImageLoader.load(url: $0) }
    let library = LogoLibrary.allEntries()
    try FileManager.default.createDirectory(at: arguments.outputDirectory, withIntermediateDirectories: true)

    for input in arguments.inputs {
        let image = try ImageLoader.load(url: input, maxPixelSize: arguments.maxPixelSize)
        let metadata = try MetadataReader.read(url: input)
        // 没有用 --logo 指定时，按照片的相机品牌从 Logo 库里自动匹配
        let matched = LogoLibrary.match(make: metadata.make, in: library).flatMap { try? ImageLoader.load(url: $0.url) }
        let logo = fixedLogo ?? matched
        for template in templates {
            let rendered = try WatermarkRenderer.render(
                image: image, metadata: metadata, template: template, options: arguments.options, logo: logo
            )
            let output = ImageExporter.outputURL(
                for: input, templateID: template.id, format: arguments.format, in: arguments.outputDirectory
            )
            try ImageExporter.export(
                rendered, to: output, format: arguments.format, quality: arguments.quality, sourceURL: input
            )
            print(output.path)
        }
    }
}

func run(_ arguments: [String]) throws {
    guard let command = arguments.first else { throw CLIError.usage("缺少命令") }
    let rest = Array(arguments.dropFirst())

    switch command {
    case "list":
        for template in TemplateStore.load().templates {
            print("\(template.id)\t\(template.name)\t\(template.summary)")
        }
    case "render":
        try runRender(rest)
    case "export-templates":
        let directory = rest.first.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? TemplateStore.userDirectory
        let written = try TemplateStore.exportBuiltins(to: directory)
        print("已写入 \(written) 个模板到 \(directory.path)")
    case "logos":
        for entry in LogoLibrary.allEntries() { print("\(entry.name)\t\(entry.url.path)") }
    case "sample":
        guard let path = rest.first else { throw CLIError.usage("sample 需要输出路径") }
        try SampleImage.write(to: URL(fileURLWithPath: path))
        print(path)
    case "help", "--help", "-h":
        print(usageText)
    default:
        throw CLIError.usage("未知命令：\(command)")
    }
}

do {
    try run(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
