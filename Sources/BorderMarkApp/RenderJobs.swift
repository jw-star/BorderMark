import BorderMarkCore
import CoreGraphics
import Foundation

struct PhotoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let metadata: PhotoMetadata
    let thumbnail: CGImage?

    var name: String { url.lastPathComponent }
}

/// 一次"原图 → 成品文件"的导出任务。值类型，可以安全地丢到后台执行。
struct ExportJob: Sendable {
    let source: URL
    let metadata: PhotoMetadata
    let template: Template
    let options: RenderOptions
    let logo: CGImage?
    let format: ExportFormat
    let quality: Double
    let output: URL
}

/// 所有耗时操作都放在这里，`nonisolated async` 保证它们不占用主线程。
enum RenderJobs {
    static let listThumbnailSize = 160
    static let templateThumbnailSize = 360
    static let previewSize = 2000

    nonisolated static func loadItem(_ url: URL) async -> Result<PhotoItem, BorderMarkError> {
        do {
            let metadata = try MetadataReader.read(url: url)
            let thumbnail = try ImageLoader.load(url: url, maxPixelSize: listThumbnailSize)
            return .success(PhotoItem(id: UUID(), url: url, metadata: metadata, thumbnail: thumbnail))
        } catch {
            return .failure(.unreadableImage(url))
        }
    }

    /// 按原始分辨率解码（已按 EXIF 方向摆正）
    nonisolated static func loadImage(_ url: URL) async -> CGImage? {
        try? ImageLoader.load(url: url)
    }

    nonisolated static func loadImage(_ url: URL, maxPixelSize: Int) async -> CGImage? {
        try? ImageLoader.load(url: url, maxPixelSize: maxPixelSize)
    }

    nonisolated static func render(
        image: CGImage, metadata: PhotoMetadata, template: Template, options: RenderOptions, logo: CGImage?
    ) async -> Result<CGImage, BorderMarkError> {
        do {
            return .success(try WatermarkRenderer.render(
                image: image, metadata: metadata, template: template, options: options, logo: logo
            ))
        } catch let error as BorderMarkError {
            return .failure(error)
        } catch {
            return .failure(.renderFailed(error.localizedDescription))
        }
    }

    nonisolated static func renderThumbnails(
        image: CGImage, metadata: PhotoMetadata, templates: [Template], options: RenderOptions,
        lineOverrides: [String: [Int: String]], logo: CGImage?
    ) async -> [String: CGImage] {
        var result: [String: CGImage] = [:]
        for template in templates {
            if Task.isCancelled { break }
            var templateOptions = options
            templateOptions.lineOverrides = lineOverrides[template.id] ?? [:]
            result[template.id] = try? WatermarkRenderer.render(
                image: image, metadata: metadata, template: template, options: templateOptions, logo: logo
            )
        }
        return result
    }

    /// 成功返回 `nil`，失败返回给用户看的原因。
    nonisolated static func perform(_ job: ExportJob) async -> String? {
        do {
            let image = try ImageLoader.load(url: job.source)
            let rendered = try WatermarkRenderer.render(
                image: image, metadata: job.metadata, template: job.template, options: job.options, logo: job.logo
            )
            try ImageExporter.export(
                rendered, to: job.output, format: job.format, quality: job.quality, sourceURL: job.source
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// 把拖进来的文件和文件夹展开成受支持的图片列表（文件夹只看一层）。
    nonisolated static func expandImageURLs(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
            guard isDirectory.boolValue else { return [url] }
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            return children.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        .filter(ImageLoader.isSupported)
    }
}
