import AppKit
import BorderMarkCore
import SwiftUI

/// Logo 的来源
enum LogoChoice: Hashable {
    /// 按照片的相机品牌自动从 Logo 库里找
    case auto
    /// 不用图片，用品牌名文字
    case text
    /// 指定 Logo 库里的某一张
    case library(String)
    /// 用户临时选的一张图片
    case custom
}

/// 导出弹窗的三个阶段
enum ExportPhase: Equatable {
    case idle
    case running
    case finished
}

/// 一次导出的进度与结果，供弹窗显示。
struct ExportReport: Equatable {
    var total = 0
    var finished = 0
    var failures: [String] = []
    /// 单张导出时是文件，批量导出时是文件夹
    var location: URL?
    var isBatch = false
    var wasCancelled = false

    var succeeded: Int { finished - failures.count }
    var progress: Double { total > 0 ? Double(finished) / Double(total) : 0 }
}

@MainActor
final class AppState: ObservableObject {
    private static let previewDebounce = Duration.milliseconds(40)
    private static let thumbnailDebounce = Duration.milliseconds(300)
    private static let maxConcurrentExports = 3
    private static let openEnvironmentKey = "BORDERMARK_OPEN"
    private static let logoEnvironmentKey = "BORDERMARK_LOGO"
    private static let exportEnvironmentKey = "BORDERMARK_EXPORT_TO"
    private static let defaultTemplateID = "blur-card"
    private static let defaultExportFormat = ExportFormat.jpeg
    static let defaultLogoColor = "#000000"
    private static let defaultExportQuality = 1.0

    @Published private(set) var photos: [PhotoItem] = []
    @Published var selectedPhotoID: PhotoItem.ID? {
        didSet { if selectedPhotoID != oldValue { reloadSelectedSources() } }
    }

    @Published private(set) var templates: [Template] = BuiltinTemplates.all
    @Published private(set) var templateProblems: [String] = []
    @Published var selectedTemplateID: String = AppState.defaultTemplateID {
        didSet { if selectedTemplateID != oldValue { schedulePreview() } }
    }

    @Published var options = RenderOptions(logoColor: AppState.defaultLogoColor, author: NSFullUserName()) {
        didSet {
            guard options != oldValue else { return }
            schedulePreview()
            if thumbnailOptions(from: options) != thumbnailOptions(from: oldValue) { scheduleThumbnails() }
        }
    }

    @Published var logoChoice = LogoChoice.auto {
        didSet {
            guard logoChoice != oldValue else { return }
            schedulePreview()
            scheduleThumbnails()
        }
    }
    @Published private(set) var logoLibrary: [LogoEntry] = []
    @Published private(set) var customLogoName: String?
    private var customLogo: CGImage?
    private var logoCache: [URL: CGImage] = [:]

    @Published private(set) var preview: CGImage?
    @Published private(set) var templateThumbnails: [String: CGImage] = [:]

    /// 每个模板各自的逐行文字改写：模板 id → 行号 → 文字
    @Published private(set) var lineOverrides: [String: [Int: String]] = [:] {
        didSet {
            guard lineOverrides != oldValue else { return }
            schedulePreview()
            scheduleThumbnails()
        }
    }

    @Published var exportFormat = AppState.defaultExportFormat
    @Published var exportQuality = AppState.defaultExportQuality
    @Published private(set) var exportPhase = ExportPhase.idle
    @Published private(set) var exportReport = ExportReport()
    private var exportTask: Task<Void, Never>?
    private var didRunLaunchExport = false
    @Published private(set) var status = "拖入照片或文件夹开始"
    @Published var alertMessage: String?

    private var previewSource: CGImage?
    private var thumbnailSource: CGImage?
    private var sourceTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?

    init() {
        reloadLogos()
        reloadTemplates()
        // 调试用：`BORDERMARK_OPEN=/a.jpg:/b.jpg` 启动即导入。
        // 不能用命令行参数传路径：AppKit 会把它当成"打开文档"，主窗口就不创建了。
        let launchPaths = ProcessInfo.processInfo.environment[Self.openEnvironmentKey]?.split(separator: ":") ?? []
        if !launchPaths.isEmpty { importPhotos(launchPaths.map { URL(fileURLWithPath: String($0)) }) }
        // 调试用：`BORDERMARK_LOGO=sony` 启动即指定 Logo，和在下拉菜单里选择走同一条路径
        if let logoID = ProcessInfo.processInfo.environment[Self.logoEnvironmentKey],
           logoLibrary.contains(where: { $0.id == logoID }) {
            logoChoice = .library(logoID)
        }
    }

    var isExporting: Bool { exportPhase == .running }

    var selectedPhoto: PhotoItem? { photos.first { $0.id == selectedPhotoID } }
    var selectedTemplate: Template { templates.first { $0.id == selectedTemplateID } ?? templates[0] }

    // MARK: - 导入

    func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "导入"
        guard panel.runModal() == .OK else { return }
        importPhotos(panel.urls)
    }

    func importPhotos(_ urls: [URL]) {
        let known = Set(photos.map(\.url))
        let candidates = RenderJobs.expandImageURLs(urls).filter { !known.contains($0) }
        guard !candidates.isEmpty else {
            status = "没有找到新的可导入图片"
            return
        }
        status = "正在导入 \(candidates.count) 张…"

        Task {
            var failures: [String] = []
            for url in candidates {
                switch await RenderJobs.loadItem(url) {
                case .success(let item):
                    photos.append(item)
                    if selectedPhotoID == nil { selectedPhotoID = item.id }
                case .failure(let error):
                    failures.append(error.localizedDescription)
                }
            }
            status = "共 \(photos.count) 张照片"
            if !failures.isEmpty { alertMessage = failures.joined(separator: "\n") }
            runLaunchExportIfRequested()
        }
    }

    /// 调试用：`BORDERMARK_EXPORT_TO=/目录` 时，启动导入完成后自动批量导出一次，用来在没有人点按钮的环境里走通导出流程。
    private func runLaunchExportIfRequested() {
        guard !didRunLaunchExport, !photos.isEmpty,
              let path = ProcessInfo.processInfo.environment[Self.exportEnvironmentKey], !path.isEmpty
        else { return }
        didRunLaunchExport = true
        exportAll(to: URL(fileURLWithPath: path, isDirectory: true))
    }

    func remove(_ item: PhotoItem) {
        photos.removeAll { $0.id == item.id }
        if selectedPhotoID == item.id { selectedPhotoID = photos.first?.id }
        status = "共 \(photos.count) 张照片"
    }

    func removeAll() {
        photos = []
        selectedPhotoID = nil
        status = "拖入照片或文件夹开始"
    }

    // MARK: - 模板与 Logo

    func reloadTemplates() {
        let result = TemplateStore.load()
        templates = result.templates
        templateProblems = result.problems
        if !templates.contains(where: { $0.id == selectedTemplateID }) {
            selectedTemplateID = templates[0].id
        }
        schedulePreview()
        scheduleThumbnails()
    }

    func exportBuiltinTemplates() {
        do {
            let written = try TemplateStore.exportBuiltins()
            status = written > 0 ? "已写出 \(written) 个示例模板" : "示例模板已存在"
            revealTemplatesFolder()
        } catch {
            alertMessage = "写出模板失败：\(error.localizedDescription)"
        }
    }

    func revealTemplatesFolder() {
        let directory = TemplateStore.userDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        } catch {
            alertMessage = "无法打开模板文件夹：\(error.localizedDescription)"
        }
    }

    func reloadLogos() {
        logoLibrary = LogoLibrary.allEntries()
        logoCache = [:]
        if case .library(let id) = logoChoice, !logoLibrary.contains(where: { $0.id == id }) {
            logoChoice = .auto
        }
        schedulePreview()
        scheduleThumbnails()
    }

    func revealLogosFolder() {
        let directory = LogoLibrary.userDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        } catch {
            alertMessage = "无法打开 Logo 文件夹：\(error.localizedDescription)"
        }
    }

    func presentLogoPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.prompt = "选择 Logo"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            customLogo = try ImageLoader.load(url: url)
            customLogoName = url.lastPathComponent
            logoChoice = .custom
            // 已经是 .custom 时 didSet 不会触发，手动刷新
            schedulePreview()
            scheduleThumbnails()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func clearCustomLogo() {
        customLogo = nil
        customLogoName = nil
        if logoChoice == .custom { logoChoice = .auto }
    }

    /// 当前选择下，某张照片该用哪张 Logo 图片；返回 `nil` 表示用品牌名文字。
    /// 自动模式按每张照片各自的品牌匹配，所以批量导出时不同相机的照片会用各自的 Logo。
    func logo(for metadata: PhotoMetadata) -> CGImage? {
        switch logoChoice {
        case .text:
            return nil
        case .custom:
            return customLogo
        case .library(let id):
            return image(for: logoLibrary.first { $0.id == id })
        case .auto:
            let override = options.fieldOverrides["Make"]?.trimmingCharacters(in: .whitespaces) ?? ""
            let make = override.isEmpty ? metadata.make : override
            return image(for: LogoLibrary.match(make: make, in: logoLibrary))
        }
    }

    private func image(for entry: LogoEntry?) -> CGImage? {
        guard let entry else { return nil }
        if let cached = logoCache[entry.url] { return cached }
        guard let loaded = try? ImageLoader.load(url: entry.url) else { return nil }
        logoCache[entry.url] = loaded
        return loaded
    }

    /// 把所有可调参数恢复成默认值。用户输入的文字内容（署名、自定义文字、手填的拍摄信息）和照片列表不动。
    func resetToDefaults() {
        options = RenderOptions(
            logoColor: Self.defaultLogoColor,
            author: options.author, customText: options.customText, fieldOverrides: options.fieldOverrides
        )
        lineOverrides = [:]
        logoChoice = .auto
        exportFormat = Self.defaultExportFormat
        exportQuality = Self.defaultExportQuality
        status = "已恢复默认参数"
    }

    // MARK: - 逐行文字

    /// 当前模板某一行正在使用的文字（改写过的优先）。
    func lineText(for slot: TextLineSlot) -> String {
        lineOverrides[selectedTemplateID]?[slot.id] ?? slot.text
    }

    func isLineOverridden(_ slot: TextLineSlot) -> Bool {
        lineOverrides[selectedTemplateID]?[slot.id] != nil
    }

    func setLineText(_ text: String, for slot: TextLineSlot) {
        let current = lineOverrides[selectedTemplateID] ?? [:]
        // 改回模板原文就等于没改，不留覆盖记录
        let updated = text == slot.text
            ? current.filter { $0.key != slot.id }
            : current.merging([slot.id: text]) { _, new in new }
        lineOverrides = lineOverrides.merging([selectedTemplateID: updated]) { _, new in new }
    }

    func resetLines() {
        lineOverrides = lineOverrides.filter { $0.key != selectedTemplateID }
    }

    /// 界面选项加上指定模板的逐行改写，就是这个模板实际渲染用的选项。
    private func effectiveOptions(forTemplate templateID: String) -> RenderOptions {
        var result = options
        result.lineOverrides = lineOverrides[templateID] ?? [:]
        return result
    }


    // MARK: - 预览

    private func reloadSelectedSources() {
        sourceTask?.cancel()
        previewSource = nil
        thumbnailSource = nil
        guard let photo = selectedPhoto else {
            preview = nil
            templateThumbnails = [:]
            return
        }
        sourceTask = Task {
            async let large = RenderJobs.loadImage(photo.url, maxPixelSize: RenderJobs.previewSize)
            async let small = RenderJobs.loadImage(photo.url, maxPixelSize: RenderJobs.templateThumbnailSize)
            let (largeImage, smallImage) = await (large, small)
            guard !Task.isCancelled, selectedPhotoID == photo.id else { return }
            previewSource = largeImage
            thumbnailSource = smallImage
            schedulePreview()
            scheduleThumbnails()
        }
    }

    private func schedulePreview() {
        previewTask?.cancel()
        guard let image = previewSource, let photo = selectedPhoto else { return }
        let template = selectedTemplate
        let currentOptions = effectiveOptions(forTemplate: template.id)
        let currentLogo = logo(for: photo.metadata)
        previewTask = Task {
            try? await Task.sleep(for: Self.previewDebounce)
            guard !Task.isCancelled else { return }
            let result = await RenderJobs.render(
                image: image, metadata: photo.metadata, template: template, options: currentOptions, logo: currentLogo
            )
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let rendered): preview = rendered
            case .failure(let error): status = error.localizedDescription
            }
        }
    }

    /// 模板缩略图只反映"模板本身的样子 + 文字内容"，不跟着滑块变，避免拖动时全部重画。
    private func thumbnailOptions(from options: RenderOptions) -> RenderOptions {
        RenderOptions(
            isLogoVisible: options.isLogoVisible,
            isLogoTinted: options.isLogoTinted,
            logoColor: options.logoColor,
            author: options.author,
            customText: options.customText,
            fieldOverrides: options.fieldOverrides
        )
    }

    private func scheduleThumbnails() {
        thumbnailTask?.cancel()
        guard let image = thumbnailSource, let photo = selectedPhoto else { return }
        let currentTemplates = templates
        let currentOptions = thumbnailOptions(from: options)
        let currentLineOverrides = lineOverrides
        let currentLogo = logo(for: photo.metadata)
        thumbnailTask = Task {
            try? await Task.sleep(for: Self.thumbnailDebounce)
            guard !Task.isCancelled else { return }
            let rendered = await RenderJobs.renderThumbnails(
                image: image, metadata: photo.metadata, templates: currentTemplates,
                options: currentOptions, lineOverrides: currentLineOverrides, logo: currentLogo
            )
            guard !Task.isCancelled else { return }
            templateThumbnails = rendered
        }
    }

    // MARK: - 导出

    func exportSelected() {
        guard let photo = selectedPhoto, !isExporting else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ImageExporter.outputURL(
            for: photo.url, templateID: selectedTemplateID, format: exportFormat,
            in: photo.url.deletingLastPathComponent()
        ).lastPathComponent
        guard panel.runModal() == .OK, let output = panel.url else { return }
        run([job(for: photo, output: output)], location: output, isBatch: false)
    }

    func exportAll() {
        guard !photos.isEmpty, !isExporting else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "导出到此文件夹"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        exportAll(to: directory)
    }

    private func exportAll(to directory: URL) {
        let jobs = photos.map { photo in
            job(for: photo, output: ImageExporter.outputURL(
                for: photo.url, templateID: selectedTemplateID, format: exportFormat, in: directory
            ))
        }
        run(jobs, location: directory, isBatch: true)
    }

    /// 取消后不再开始新的照片；已经在处理的几张会做完。
    func cancelExport() {
        exportTask?.cancel()
    }

    func dismissExportReport() {
        guard exportPhase == .finished else { return }
        exportPhase = .idle
    }

    func revealExportLocation() {
        guard let location = exportReport.location else { return }
        if exportReport.isBatch {
            NSWorkspace.shared.open(location)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([location])
        }
    }

    private func job(for photo: PhotoItem, output: URL) -> ExportJob {
        ExportJob(
            source: photo.url, metadata: photo.metadata, template: selectedTemplate,
            options: effectiveOptions(forTemplate: selectedTemplateID),
            logo: logo(for: photo.metadata), format: exportFormat, quality: exportQuality, output: output
        )
    }

    /// 限制并发数：原图解码很吃内存，同时处理太多会把内存撑爆。
    private func run(_ jobs: [ExportJob], location: URL, isBatch: Bool) {
        exportReport = ExportReport(total: jobs.count, location: location, isBatch: isBatch)
        exportPhase = .running
        status = "正在导出 \(jobs.count) 张…"

        exportTask = Task {
            var pending = jobs[...]

            await withTaskGroup(of: String?.self) { group in
                for _ in 0..<min(Self.maxConcurrentExports, jobs.count) {
                    guard let next = pending.popFirst() else { break }
                    group.addTask { await RenderJobs.perform(next) }
                }
                for await failure in group {
                    exportReport.finished += 1
                    if let failure { exportReport.failures.append(failure) }
                    if !Task.isCancelled, let next = pending.popFirst() {
                        group.addTask { await RenderJobs.perform(next) }
                    }
                }
            }

            let report = exportReport
            exportReport.wasCancelled = report.finished < report.total
            exportPhase = .finished
            status = report.failures.isEmpty
                ? "已导出 \(report.succeeded) 张"
                : "导出 \(report.succeeded) 张，失败 \(report.failures.count) 张"
        }
    }
}
