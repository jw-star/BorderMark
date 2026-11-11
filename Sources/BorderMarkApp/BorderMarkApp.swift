import AppKit
import SwiftUI

@main
struct BorderMarkApp: App {
    @StateObject private var state = AppState()

    init() {
        // 用 `swift run` 直接启动（没有 .app 包）时，也要作为普通前台应用出现
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        WindowSnapshot.scheduleIfRequested()
    }

    var body: some Scene {
        WindowGroup("边框水印大师") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入照片…") { state.presentImportPanel() }
                    .keyboardShortcut("o")
                Button("导出当前照片…") { state.exportSelected() }
                    .keyboardShortcut("e")
                    .disabled(state.selectedPhoto == nil)
                Button("批量导出全部…") { state.exportAll() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(state.photos.isEmpty)
            }
        }
    }
}
