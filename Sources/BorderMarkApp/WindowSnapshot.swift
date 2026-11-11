import AppKit

/// 调试用：设置环境变量 `BORDERMARK_SNAPSHOT=/path/out.png` 启动时，
/// 等界面稳定后把主窗口内容存成 PNG 并退出。用于在没有屏幕录制权限的环境（如 CI）里检查界面。
@MainActor
enum WindowSnapshot {
    private static let environmentKey = "BORDERMARK_SNAPSHOT"
    private static let sizeEnvironmentKey = "BORDERMARK_SNAPSHOT_SIZE"
    private static let settleDelay = Duration.seconds(4)

    static func scheduleIfRequested() {
        guard let path = ProcessInfo.processInfo.environment[environmentKey], !path.isEmpty else { return }
        Task {
            try? await Task.sleep(for: settleDelay)
            let succeeded = capture(to: URL(fileURLWithPath: path))
            exit(succeeded ? 0 : 1)
        }
    }

    private static var requestedSize: CGSize? {
        let parts = (ProcessInfo.processInfo.environment[sizeEnvironmentKey] ?? "").split(separator: "x")
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0
        else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func capture(to url: URL) -> Bool {
        let windows = NSApplication.shared.windows
        // 有弹窗（如导出进度）时截弹窗，否则截主窗口
        let window = windows.first { $0.isSheet && $0.isVisible }
            ?? windows.first(where: \.isVisible)
            ?? windows.first { $0.contentView != nil }
        // `BORDERMARK_SNAPSHOT_SIZE=1300x2400`：先把窗口撑到指定大小，方便一次看全很长的侧栏
        if let size = requestedSize {
            // 有标题栏的窗口会被限制在屏幕高度内，去掉边框才能撑到任意大小
            window?.styleMask = [.borderless]
            window?.setContentSize(size)
            window?.contentView?.layoutSubtreeIfNeeded()
        }
        guard let view = window?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else {
            FileHandle.standardError.write(Data("截图失败：窗口数 \(windows.count)\n".utf8))
            return false
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }
}
