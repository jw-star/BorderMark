import BorderMarkCore
import SwiftUI

struct InspectorView: View {
    /// 允许手动覆盖的 EXIF 字段：占位符名 → 界面标题
    private static let overridableFields: [(key: String, title: String)] = [
        ("Make", "品牌"), ("Model", "机型"), ("Lens", "镜头"),
        ("FocalLength", "焦距"), ("FNumber", "光圈"), ("Shutter", "快门"), ("ISO", "感光度"),
        ("DateTime", "时间"),
    ]

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("水印模式") { TemplatePickerView() }
                    section("调整", accessory: { resetButton }) { AdjustmentsView() }
                    section("文字行") { TextLinesView() }
                    section("文字内容") { textFields }
                    section("导出设置") { exportSettings }
                    section("自定义模板") { templateFiles }
                }
                .padding(16)
            }
            Divider()
            exportBar
        }
        .background(.background)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        section(title, accessory: { EmptyView() }, content: content)
    }

    private func section<Accessory: View, Content: View>(
        _ title: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                accessory()
            }
            content()
        }
    }

    private var resetButton: some View {
        Button("重置默认") { state.resetToDefaults() }
            .controlSize(.small)
            .help("把调整、文字行、Logo 和导出设置恢复成默认值；已输入的署名等文字内容保留")
    }

    // MARK: - 导出按钮

    /// 固定在面板底部，滚到哪里都能直接导出。
    private var exportBar: some View {
        VStack(spacing: 8) {
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
        }
        .padding(12)
    }

    // MARK: - 文字内容

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledField("署名", text: $state.options.author, prompt: "用于 © 版权行")
            labeledField("自定义文字", text: $state.options.customText, prompt: "拍立得标题、水印附言")

            DisclosureGroup("手动填写拍摄信息") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.overridableFields, id: \.key) { field in
                        labeledField(field.title, text: overrideBinding(field.key), prompt: detectedValue(field.key))
                    }
                    Text("留空则使用照片自带的 EXIF。填写后对所有照片生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            .font(.callout)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        }
    }

    private func overrideBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { state.options.fieldOverrides[key] ?? "" },
            set: { newValue in
                state.options.fieldOverrides = state.options.fieldOverrides.merging([key: newValue]) { _, new in new }
            }
        )
    }

    /// 当前照片 EXIF 里读到的值，作为输入框的占位提示。
    private func detectedValue(_ key: String) -> String {
        guard let photo = state.selectedPhoto else { return "未选择照片" }
        let value = PlaceholderResolver(metadata: photo.metadata).values[key] ?? ""
        return value.isEmpty ? "未读到" : value
    }

    // MARK: - 导出

    private var exportSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("格式", selection: $state.exportFormat) {
                ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            if state.exportFormat.isLossy {
                HStack {
                    Text("质量")
                    Slider(value: $state.exportQuality, in: 0.5...1)
                        .accessibilityLabel("导出质量")
                    Text("\(Int((state.exportQuality * 100).rounded()))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
                .font(.callout)
            }
            Text("按原图分辨率导出，并保留原图的 EXIF。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 模板文件

    private var templateFiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每个模式是一份 JSON。把文件放进模板文件夹后点“重新加载”，同 id 会覆盖内置模式。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
}
