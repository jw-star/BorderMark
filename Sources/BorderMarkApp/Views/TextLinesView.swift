import BorderMarkCore
import SwiftUI

/// 逐行编辑当前模式里的文字：每一行可以直接改，也可以从预设里选。
struct TextLinesView: View {
    private static let presets: [(title: String, text: String)] = [
        ("完整相机名", "{Camera}"),
        ("机型", "{Model}"),
        ("品牌", "{Make}"),
        ("镜头", "{Lens}"),
        ("拍摄参数", "{Params}"),
        ("拍摄时间", "{DateTime}"),
        ("拍摄日期", "{Date}"),
        ("位置", "{GPS}"),
        ("版权署名", "{Copyright}"),
        ("自定义文字", "{Custom}"),
        ("相机名 · 参数", "{Camera}  ·  {Params}"),
    ]

    @EnvironmentObject private var state: AppState

    var body: some View {
        let slots = state.selectedTemplate.textLineSlots
        VStack(alignment: .leading, spacing: 10) {
            if slots.isEmpty {
                Text("这个模式没有可以逐行编辑的文字。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(slots) { slot in
                    row(for: slot)
                }
                Text("花括号里是占位符，会替换成照片的信息；清空则这一行不显示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("恢复这个模式的原始文字") { state.resetLines() }
                    .controlSize(.small)
                    .disabled(!slots.contains(where: state.isLineOverridden))
            }
        }
    }

    private func row(for slot: TextLineSlot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label(for: slot))
                .font(.caption)
                .foregroundStyle(state.isLineOverridden(slot) ? Color.accentColor : Color.secondary)
            HStack(spacing: 6) {
                TextField(label(for: slot), text: binding(for: slot), prompt: Text("不显示"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .font(.system(.callout, design: .monospaced))
                Menu {
                    ForEach(Self.presets, id: \.text) { preset in
                        Button(preset.title) { state.setLineText(preset.text, for: slot) }
                    }
                    Divider()
                    Button("不显示这一行") { state.setLineText("", for: slot) }
                    Button("恢复原始文字") { state.setLineText(slot.text, for: slot) }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("从预设里选内容")
                .accessibilityLabel("\(label(for: slot))的预设内容")
            }
        }
    }

    private func binding(for slot: TextLineSlot) -> Binding<String> {
        Binding(get: { state.lineText(for: slot) }, set: { state.setLineText($0, for: slot) })
    }

    /// 例如"底栏 · 右 · 第 1 行"
    private func label(for slot: TextLineSlot) -> String {
        let region: String
        switch slot.region {
        case .top: region = "顶栏"
        case .bottom: region = "底栏"
        case .left: region = "左栏"
        case .right: region = "右栏"
        case .photo: region = "照片内"
        case .canvas: region = "画布"
        }
        let side: String
        switch slot.h {
        case .leading: side = "左"
        case .center: side = "中"
        case .trailing: side = "右"
        }
        return "\(region) · \(side) · 第 \(slot.row + 1) 行"
    }
}
