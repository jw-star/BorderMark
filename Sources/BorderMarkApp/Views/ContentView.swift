import BorderMarkCore
import SwiftUI

struct ContentView: View {
    private static let photoListWidth: CGFloat = 200
    private static let inspectorWidth: CGFloat = 350

    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            PhotoListView()
                .frame(width: Self.photoListWidth)
            Divider()
            PreviewView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            InspectorView()
                .frame(width: Self.inspectorWidth)
        }
        .overlay {
            if state.isFullScreenPreview {
                FullScreenPreviewView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.isFullScreenPreview)
        .toolbar { toolbarContent }
        .dropDestination(for: URL.self) { urls, _ in
            state.importPhotos(urls)
            return true
        }
        .sheet(isPresented: exportSheetBinding) {
            ExportProgressView()
                .environmentObject(state)
        }
        .alert("出了点问题", isPresented: alertBinding) {
            Button("好") { state.alertMessage = nil }
        } message: {
            Text(state.alertMessage ?? "")
        }
    }

    private var exportSheetBinding: Binding<Bool> {
        Binding(get: { state.exportPhase != .idle }, set: { if !$0 { state.dismissExportReport() } })
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { state.alertMessage != nil }, set: { if !$0 { state.alertMessage = nil } })
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { state.presentImportPanel() } label: {
                Label("导入", systemImage: "plus")
            }
            .help("导入照片或文件夹（⌘O）")
        }
        ToolbarItem(placement: .primaryAction) {
            Button { state.enterFullScreenPreview() } label: {
                Label("全屏预览", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(state.selectedPhoto == nil)
            .help("全屏预览（空格）；方向键切换照片")
        }
    }
}
