import BorderMarkCore
import SwiftUI

/// 右侧面板：顶部按功能分页，每页的参数用卡片分组，底部固定导出按钮。
struct InspectorView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case templates = "模式"
        case style = "样式"
        case logo = "Logo"
        case text = "文字"
        case export = "导出"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .templates: return "square.grid.2x2"
            case .style: return "slider.horizontal.3"
            case .logo: return "seal"
            case .text: return "textformat"
            case .export: return "square.and.arrow.up"
            }
        }

        var summary: String {
            switch self {
            case .templates: return "选择水印版式"
            case .style: return "边框、背景与文字样式"
            case .logo: return "品牌 Logo 的来源、样式和颜色"
            case .text: return "每一行显示什么内容"
            case .export: return "导出格式与质量"
            }
        }
    }

    @EnvironmentObject private var state: AppState
    @AppStorage("inspectorTab") private var tab = Tab.templates

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(14)
            }
            Divider()
            exportBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { FocusReset.clearAfterLayout() }
        .onChange(of: tab) { FocusReset.clearAfterLayout() }
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("分类", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab == .templates ? state.selectedTemplate.name : tab.rawValue)
                        .font(.headline)
                    Text(tab == .templates ? state.selectedTemplate.summary : tab.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("重置默认") { state.resetToDefaults() }
                    .controlSize(.small)
                    .help("把样式、Logo、文字行和导出设置恢复成默认值；已输入的署名等文字内容保留")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .templates:
            VStack(spacing: 12) {
                TemplatePickerView()
                templateFilesCard
            }
        case .style:
            StyleSettingsView()
        case .logo:
            LogoSettingsView()
        case .text:
            TextSettingsView()
        case .export:
            exportSettingsCard
        }
    }

    // MARK: - 模式页

    private var templateFilesCard: some View {
        SettingsCard("自定义模式", systemImage: "doc.badge.gearshape") {
            HintText("每个模式是一份 JSON。放进模板文件夹后点“重新加载”，同 id 会覆盖内置模式。")
            HStack {
                Button("写出示例") { state.exportBuiltinTemplates() }
                    .help("把内置模式写成 JSON 文件，方便照着改")
                Button("打开文件夹") { state.revealTemplatesFolder() }
                Button("重新加载") { state.reloadTemplates() }
            }
            .controlSize(.small)
            ForEach(state.templateProblems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 导出页

    private var exportSettingsCard: some View {
        SettingsCard("格式与质量", systemImage: "photo") {
            Picker("格式", selection: $state.exportFormat) {
                ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            if state.exportFormat.isLossy {
                SliderRow(title: "质量", value: $state.exportQuality, range: 0.5...1) {
                    "\(Int(($0 * 100).rounded()))"
                }
            }
            HintText("按原图分辨率导出，并保留原图的 EXIF。")
        }
    }

    // MARK: - 导出按钮

    /// 固定在面板底部，切到哪一页都能直接导出。
    private var exportBar: some View {
        HStack(spacing: 8) {
            Button { state.exportSelected() } label: {
                Label("导出当前", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.selectedPhoto == nil || state.isExporting)
            .help("导出当前照片（⌘E）")

            Button { state.exportAll() } label: {
                Text("批量导出 \(state.photos.count) 张")
                    .frame(maxWidth: .infinity)
            }
            .disabled(state.photos.isEmpty || state.isExporting)
            .help("用当前模式导出全部照片（⇧⌘E）")
        }
        .controlSize(.large)
        .padding(12)
    }
}
