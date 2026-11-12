import BorderMarkCore
import SwiftUI

/// 设置面板里的一张卡片：标题 + 可选的右上角按钮 + 内容。
struct SettingsCard<Accessory: View, Content: View>: View {
    private static var cornerRadius: CGFloat { 10 }

    let title: String
    let systemImage: String
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                accessory
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

extension SettingsCard where Accessory == EmptyView {
    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, accessory: { EmptyView() }, content: content)
    }
}

/// 带标题和当前数值的滑块。
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { String(format: "%.2f×", $0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            Slider(value: $value, in: range)
                .accessibilityLabel(title)
        }
    }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

/// 说明文字
struct HintText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 带小标题的输入框
struct LabeledField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: $text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        }
    }
}

extension AppState {
    /// 开关 ↔ 可选值：打开时写入默认值，关闭时清空。
    func optionalBinding<Value>(
        _ keyPath: WritableKeyPath<RenderOptions, Value?>, default defaultValue: Value
    ) -> Binding<Bool> {
        Binding(
            get: { self.options[keyPath: keyPath] != nil },
            set: { self.options[keyPath: keyPath] = $0 ? defaultValue : nil }
        )
    }

    func unwrapped<Value>(_ keyPath: WritableKeyPath<RenderOptions, Value?>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { self.options[keyPath: keyPath] ?? fallback },
            set: { self.options[keyPath: keyPath] = $0 }
        )
    }
}
