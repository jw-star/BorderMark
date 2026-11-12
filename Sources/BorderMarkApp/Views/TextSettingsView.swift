import BorderMarkCore
import SwiftUI

/// “文字”页：逐行内容、署名与附言、手动填写的拍摄信息。
struct TextSettingsView: View {
    /// 允许手动覆盖的 EXIF 字段：占位符名 → 界面标题
    private static let overridableFields: [(key: String, title: String)] = [
        ("Make", "品牌"), ("Model", "机型"), ("Lens", "镜头"),
        ("FocalLength", "焦距"), ("FNumber", "光圈"), ("Shutter", "快门"), ("ISO", "感光度"),
        ("DateTime", "时间"),
    ]
    private static let fieldColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard("文字行", systemImage: "list.bullet.rectangle") {
                TextLinesView()
            }

            SettingsCard("署名与附言", systemImage: "signature") {
                LabeledField(title: "署名", text: $state.options.author, prompt: "用于 © 版权行")
                LabeledField(title: "自定义文字", text: $state.options.customText, prompt: "拍立得标题、水印附言")
            }

            SettingsCard("拍摄信息", systemImage: "camera") {
                LazyVGrid(columns: Self.fieldColumns, alignment: .leading, spacing: 8) {
                    ForEach(Self.overridableFields, id: \.key) { field in
                        LabeledField(title: field.title, text: overrideBinding(field.key), prompt: detectedValue(field.key))
                    }
                }
                HintText("灰色提示是照片自带的 EXIF；填写后覆盖它，并对所有照片生效。")
            }
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

    private func detectedValue(_ key: String) -> String {
        guard let photo = state.selectedPhoto else { return "未选择照片" }
        let value = PlaceholderResolver(metadata: photo.metadata).values[key] ?? ""
        return value.isEmpty ? "未读到" : value
    }
}
