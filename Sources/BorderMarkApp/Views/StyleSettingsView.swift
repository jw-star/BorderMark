import BorderMarkCore
import SwiftUI

/// “样式”页：边框与照片、背景、文字样式。
struct StyleSettingsView: View {
    private enum BackgroundChoice: String, CaseIterable, Identifiable {
        case template = "跟随模板"
        case solid = "纯色"
        case gradient = "渐变"
        case blur = "模糊"
        case dominant = "主色"

        var id: String { rawValue }
    }

    private enum ShadowChoice: String, CaseIterable, Identifiable {
        case template = "跟随模板"
        case on = "开"
        case off = "关"

        var id: String { rawValue }
    }

    private static let weightChoices: [(title: String, weight: FontWeight)] = [
        ("细体", .light), ("常规", .regular), ("中等", .medium), ("半粗", .semibold), ("粗体", .bold),
    ]
    private static let fontChoices = ["PingFang SC", "Helvetica Neue", "Avenir Next", "Georgia", "Songti SC", "Menlo"]
    private static let defaultSolid = "#FFFFFF"
    private static let defaultGradient = (from: "#1B1F2A", to: "#3A2A45")
    private static let defaultBlur = (radius: 0.09, dim: 0.22)
    private static let defaultDim = 0.25
    private static let defaultTextColor = "#111111"
    private static let defaultCornerRadius = 0.03
    private static let maxCornerRadius = 0.15

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard("边框与照片", systemImage: "rectangle.inset.filled") {
                SliderRow(title: "边框宽度", value: $state.options.borderScale, range: 0...3)
                Toggle("自定义圆角", isOn: state.optionalBinding(\.cornerRadius, default: Self.defaultCornerRadius))
                if state.options.cornerRadius != nil {
                    SliderRow(
                        title: "圆角", value: state.unwrapped(\.cornerRadius, fallback: 0),
                        range: 0...Self.maxCornerRadius, format: SliderRow.percent
                    )
                }
                Picker("阴影", selection: shadowChoice) {
                    ForEach(ShadowChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            SettingsCard("背景", systemImage: "square.fill.on.square.fill") {
                Picker("背景", selection: backgroundChoice) {
                    ForEach(BackgroundChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                backgroundDetail
            }

            SettingsCard("文字样式", systemImage: "textformat") {
                SliderRow(title: "文字大小", value: $state.options.textScale, range: 0.4...2.5)
                Picker("字体", selection: fontBinding) {
                    Text("跟随模板").tag("")
                    Divider()
                    ForEach(Self.fontChoices, id: \.self) { Text($0).tag($0) }
                }
                Picker("粗细", selection: $state.options.fontWeight) {
                    Text("跟随模板").tag(FontWeight?.none)
                    Divider()
                    ForEach(Self.weightChoices, id: \.weight) { choice in
                        Text(choice.title).tag(FontWeight?.some(choice.weight))
                    }
                }
                Toggle("自定义文字颜色", isOn: state.optionalBinding(\.textColor, default: Self.defaultTextColor))
                if state.options.textColor != nil {
                    ColorPicker(
                        "文字颜色",
                        selection: colorBinding(state.unwrapped(\.textColor, fallback: Self.defaultTextColor))
                    )
                }
            }
        }
    }

    // MARK: - 背景

    @ViewBuilder
    private var backgroundDetail: some View {
        switch state.options.background {
        case .solid(let color):
            ColorPicker("背景颜色", selection: Binding(
                get: { Color(hex: color) },
                set: { state.options.background = .solid(color: $0.hexString) }
            ), supportsOpacity: false)
        case .gradient(let from, let to):
            ColorPicker("起始颜色", selection: Binding(
                get: { Color(hex: from) },
                set: { state.options.background = .gradient(from: $0.hexString, to: to) }
            ), supportsOpacity: false)
            ColorPicker("结束颜色", selection: Binding(
                get: { Color(hex: to) },
                set: { state.options.background = .gradient(from: from, to: $0.hexString) }
            ), supportsOpacity: false)
        case .blur(let radius, let dim):
            SliderRow(title: "模糊强度", value: Binding(
                get: { radius }, set: { state.options.background = .blur(radius: $0, dim: dim) }
            ), range: 0.01...0.25, format: SliderRow.percent)
            SliderRow(title: "压暗", value: Binding(
                get: { dim }, set: { state.options.background = .blur(radius: radius, dim: $0) }
            ), range: 0...0.8, format: SliderRow.percent)
        case .dominant(let dim):
            SliderRow(title: "压暗", value: Binding(
                get: { dim }, set: { state.options.background = .dominant(dim: $0) }
            ), range: 0...0.8, format: SliderRow.percent)
        case .none:
            HintText("使用当前模式自带的背景。")
        }
    }

    private var backgroundChoice: Binding<BackgroundChoice> {
        Binding(
            get: {
                switch state.options.background {
                case .none: return .template
                case .solid: return .solid
                case .gradient: return .gradient
                case .blur: return .blur
                case .dominant: return .dominant
                }
            },
            set: { choice in
                switch choice {
                case .template: state.options.background = nil
                case .solid: state.options.background = .solid(color: Self.defaultSolid)
                case .gradient:
                    state.options.background = .gradient(from: Self.defaultGradient.from, to: Self.defaultGradient.to)
                case .blur:
                    state.options.background = .blur(radius: Self.defaultBlur.radius, dim: Self.defaultBlur.dim)
                case .dominant: state.options.background = .dominant(dim: Self.defaultDim)
                }
            }
        )
    }

    // MARK: - 阴影 / 字体

    private var shadowChoice: Binding<ShadowChoice> {
        Binding(
            get: {
                switch state.options.isShadowEnabled {
                case .none: return .template
                case .some(true): return .on
                case .some(false): return .off
                }
            },
            set: { choice in
                switch choice {
                case .template: state.options.isShadowEnabled = nil
                case .on: state.options.isShadowEnabled = true
                case .off: state.options.isShadowEnabled = false
                }
            }
        )
    }

    private var fontBinding: Binding<String> {
        Binding(
            get: { state.options.fontName ?? "" },
            set: { state.options.fontName = $0.isEmpty ? nil : $0 }
        )
    }
}
