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
    }
}
