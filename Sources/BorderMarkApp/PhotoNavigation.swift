import AppKit

/// 照片之间的切换与全屏预览。
extension AppState {
    var selectedIndex: Int? { photos.firstIndex { $0.id == selectedPhotoID } }

    /// 往前或往后切换照片，到头时循环到另一端。
    func selectPhoto(offset: Int) {
        guard !photos.isEmpty else { return }
        let current = selectedIndex ?? (offset > 0 ? -1 : 0)
        let next = ((current + offset) % photos.count + photos.count) % photos.count
        selectedPhotoID = photos[next].id
    }

    func selectNextPhoto() { selectPhoto(offset: 1) }
    func selectPreviousPhoto() { selectPhoto(offset: -1) }

    func toggleFullScreenPreview() {
        isFullScreenPreview ? exitFullScreenPreview() : enterFullScreenPreview()
    }

    /// 进入全屏预览：主窗口不在系统全屏时顺便切过去，退出时再切回来。
    func enterFullScreenPreview() {
        guard selectedPhoto != nil, !isFullScreenPreview else { return }
        isFullScreenPreview = true
        guard let window = mainWindow, !window.styleMask.contains(.fullScreen) else { return }
        didEnterSystemFullScreen = true
        window.toggleFullScreen(nil)
    }

    func exitFullScreenPreview() {
        guard isFullScreenPreview else { return }
        isActualSizePreview = false
        isFullScreenPreview = false
        guard didEnterSystemFullScreen else { return }
        didEnterSystemFullScreen = false
        if let window = mainWindow, window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
    }

    private var mainWindow: NSWindow? {
        NSApplication.shared.windows.first { $0.isVisible && !$0.isSheet && $0.canBecomeMain }
    }
}

/// 输入框焦点管理。SwiftUI 打开窗口或切换页面时会自动把焦点放进第一个输入框，
/// 之后方向键就全被输入框吃掉了，所以在这些时机主动让输入框交出焦点。
@MainActor
enum FocusReset {
    /// 等 SwiftUI 完成这一轮布局（它会在布局之后自动聚焦）再清掉
    private static let settleDelay = Duration.milliseconds(150)

    static func clear() {
        for window in NSApplication.shared.windows where window.isVisible && !window.isSheet {
            if window.firstResponder is NSText { window.makeFirstResponder(nil) }
        }
    }

    /// 窗口每次成为前台窗口时，SwiftUI 也可能重新聚焦输入框，所以一并处理。
    static func observeWindowActivation() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { clearAfterLayout() }
        }
    }

    static func clearAfterLayout() {
        Task {
            try? await Task.sleep(for: settleDelay)
            clear()
        }
    }
}

/// 全局键盘处理：方向键切换照片，空格进入 / 退出全屏预览，Esc 退出全屏预览。
/// 正在输入文字、调滑块或有弹窗时不拦截，按键照常交给控件。
@MainActor
enum PhotoKeyboard {
    private enum Key: UInt16 {
        case space = 49
        case escape = 53
        case z = 6
        case left = 123
        case right = 124
        case down = 125
        case up = 126
    }

    private static let blockingModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static func install(for state: AppState) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak state] event in
            guard let state else { return event }
            // 本地事件监听总在主线程回调；NSEvent 没标 Sendable，这里只在主线程上同步使用它
            nonisolated(unsafe) let mainThreadEvent = event
            let isHandled = MainActor.assumeIsolated { handle(mainThreadEvent, state: state) }
            return isHandled ? nil : event
        }
    }

    /// 处理了返回 `true`，事件就不再往下传。
    private static func handle(_ event: NSEvent, state: AppState) -> Bool {
        guard let key = Key(rawValue: event.keyCode),
              event.modifierFlags.intersection(blockingModifiers).isEmpty
        else { return false }

        // 在输入框里按 Esc：退出输入，之后方向键就能切换照片了
        if key == .escape, event.window?.firstResponder is NSText, !(event.window?.isSheet ?? true) {
            event.window?.makeFirstResponder(nil)
            return true
        }
        guard !isBusy(event.window) else { return false }

        switch key {
        case .left, .up:
            state.selectPreviousPhoto()
        case .right, .down:
            state.selectNextPhoto()
        case .space:
            state.toggleFullScreenPreview()
        case .escape:
            guard state.isFullScreenPreview else { return false }
            state.exitFullScreenPreview()
        case .z:
            guard state.isFullScreenPreview else { return false }
            state.isActualSizePreview.toggle()
        }
        return true
    }

    /// 焦点在输入框、滑块等自己要用方向键的控件上，或者有弹窗时，不拦截。
    private static func isBusy(_ window: NSWindow?) -> Bool {
        guard let window else { return true }
        if window.isSheet || window.attachedSheet != nil { return true }
        switch window.firstResponder {
        case is NSText, is NSSlider, is NSStepper, is NSDatePicker: return true
        default: return false
        }
    }
}

/// 调试用：`BORDERMARK_KEYTEST=1` 时，导入完成后模拟按一次 → 键，把切换前后的照片序号和焦点控件打印到标准错误。
@MainActor
enum KeyboardSelfTest {
    private static let environmentKey = "BORDERMARK_KEYTEST"
    private static let rightArrowKeyCode: UInt16 = 124

    static func runIfRequested(state: AppState) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1" else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            let window = NSApplication.shared.windows.first { $0.isVisible }
            report("before index=\(state.selectedIndex.map(String.init) ?? "nil") photos=\(state.photos.count) "
                + "keyWindow=\(NSApplication.shared.keyWindow != nil) "
                + "firstResponder=\(window?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil")")
            guard let window,
                  let event = NSEvent.keyEvent(
                      with: .keyDown, location: .zero, modifierFlags: [.numericPad, .function],
                      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                      context: nil, characters: "\u{F703}", charactersIgnoringModifiers: "\u{F703}",
                      isARepeat: false, keyCode: rightArrowKeyCode
                  )
            else { return }
            NSApplication.shared.postEvent(event, atStart: false)
            try? await Task.sleep(for: .seconds(1))
            report("after index=\(state.selectedIndex.map(String.init) ?? "nil")")

            // 100% 查看：进入全屏后打开 100%，等原图分辨率渲染完成
            state.enterFullScreenPreview()
            state.isActualSizePreview = true
            for _ in 0..<40 where state.fullResolutionPreview == nil { try? await Task.sleep(for: .milliseconds(250)) }
            try? await Task.sleep(for: .seconds(1))
            let full = state.fullResolutionPreview
            let scroll = NSApplication.shared.windows.lazy.compactMap { $0.contentView?.firstDescendant(ZoomScrollView.self) }.first
            report("fullResolution=\(full.map { "\($0.width)x\($0.height)" } ?? "nil") "
                + "preview=\(state.preview.map { "\($0.width)x\($0.height)" } ?? "nil") "
                + "magnification=\(scroll.map { String(format: "%.2f", $0.magnification) } ?? "nil")")
            state.exitFullScreenPreview()
            report("mainWindow showing=\(state.displayPreview.map { "\($0.width)x\($0.height)" } ?? "nil") "
                + "fullResolution=\(state.isShowingFullResolution)")
            exit(0)
        }
    }

    private static func report(_ text: String) {
        FileHandle.standardError.write(Data("[keytest] \(text)\n".utf8))
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(_ type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstDescendant(type) { return match }
        }
        return nil
    }
}
