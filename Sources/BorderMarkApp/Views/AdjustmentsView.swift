import BorderMarkCore
import SwiftUI

/// 版式调整：边框、文字大小、背景、颜色、圆角、阴影、字体、Logo。
struct AdjustmentsView: View {
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

    private enum LogoColorMode: String, CaseIterable, Identifiable {
        case followText = "跟随文字"
        case custom = "自定义"
        case original = "原色"

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
        VStack(alignment: .leading, spacing: 12) {
            slider("边框宽度", value: $state.options.borderScale, range: 0...3)
            slider("文字大小", value: $state.options.textScale, range: 0.4...2.5)

            Picker("背景", selection: backgroundChoice) {
                ForEach(BackgroundChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            backgroundDetail

            Toggle("自定义文字颜色", isOn: optionalBinding(\.textColor, default: Self.defaultTextColor))
            if state.options.textColor != nil {
                ColorPicker("文字颜色", selection: colorBinding(unwrapped(\.textColor, fallback: Self.defaultTextColor)))
            }

            Toggle("自定义圆角", isOn: optionalBinding(\.cornerRadius, default: Self.defaultCornerRadius))
            if state.options.cornerRadius != nil {
                slider("圆角", value: unwrapped(\.cornerRadius, fallback: 0), range: 0...Self.maxCornerRadius,
                       format: { "\(Int(($0 * 100).rounded()))%" })
            }

            Picker("阴影", selection: shadowChoice) {
                ForEach(ShadowChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("字体", selection: fontBinding) {
                Text("跟随模板").tag("")
                Divider()
                ForEach(Self.fontChoices, id: \.self) { Text($0).tag($0) }
            }

            Picker("文字粗细", selection: weightBinding) {
                Text("跟随模板").tag(FontWeight?.none)
                Divider()
                ForEach(Self.weightChoices, id: \.weight) { choice in
                    Text(choice.title).tag(FontWeight?.some(choice.weight))
                }
            }

            logoRow
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
            slider("模糊强度", value: Binding(
                get: { radius }, set: { state.options.background = .blur(radius: $0, dim: dim) }
            ), range: 0.01...0.25, format: percent)
            slider("压暗", value: Binding(
                get: { dim }, set: { state.options.background = .blur(radius: radius, dim: $0) }
            ), range: 0...0.8, format: percent)
        case .dominant(let dim):
            slider("压暗", value: Binding(
                get: { dim }, set: { state.options.background = .dominant(dim: $0) }
            ), range: 0...0.8, format: percent)
        case .none:
            EmptyView()
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

    // MARK: - 阴影 / 字体 / Logo

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

    private var logoColorMode: Binding<LogoColorMode> {
        Binding(
            get: {
                guard state.options.isLogoTinted else { return .original }
                return state.options.logoColor == nil ? .followText : .custom
            },
            set: { mode in
                switch mode {
                case .followText:
                    state.options.isLogoTinted = true
                    state.options.logoColor = nil
                case .custom:
                    state.options.isLogoTinted = true
                    state.options.logoColor = state.options.logoColor ?? AppState.defaultLogoColor
                case .original:
                    state.options.isLogoTinted = false
                }
            }
        )
    }

    private var weightBinding: Binding<FontWeight?> {
        Binding(get: { state.options.fontWeight }, set: { state.options.fontWeight = $0 })
    }

    private var fontBinding: Binding<String> {
        Binding(
            get: { state.options.fontName ?? "" },
            set: { state.options.fontName = $0.isEmpty ? nil : $0 }
        )
    }

    private var logoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("显示品牌 Logo", isOn: $state.options.isLogoVisible)
            if !state.selectedTemplate.hasLogo {
                Label("“\(state.selectedTemplate.name)”没有 Logo 位置，下面的 Logo 设置在这个模式里看不到效果。",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                Picker("Logo", selection: $state.logoChoice) {
                    Text("自动匹配相机品牌").tag(LogoChoice.auto)
                    Text("仅品牌名文字").tag(LogoChoice.text)
                    if let name = state.customLogoName {
                        Text("自选：\(name)").tag(LogoChoice.custom)
                    }
                    Divider()
                    ForEach(state.logoLibrary) { entry in
                        Text(entry.name).tag(LogoChoice.library(entry.id))
                    }
                }
                Picker("Logo 颜色", selection: logoColorMode) {
                    ForEach(LogoColorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .help("“原色”保留图片本身的颜色，适合彩色 Logo；其余两项只对透明底的 Logo 生效")
                if let color = state.options.logoColor, state.options.isLogoTinted {
                    ColorPicker("自定义颜色", selection: Binding(
                        get: { Color(hex: color) },
                        set: { state.options.logoColor = $0.hexString }
                    ), supportsOpacity: false)
                }
                HStack {
                    Button("选择图片…") { state.presentLogoPanel() }
                    if state.customLogoName != nil {
                        Button("移除自选") { state.clearCustomLogo() }
                    }
                    Button("Logo 文件夹") { state.revealLogosFolder() }
                        .help("把 Nikon.png 这样以品牌命名的图片放进去，同名会替换内置的")
                    Button { state.reloadLogos() } label: { Image(systemName: "arrow.clockwise") }
                        .help("重新加载 Logo 库")
                        .accessibilityLabel("重新加载 Logo 库")
                }
                .controlSize(.small)
            }
            .disabled(!state.options.isLogoVisible)

            Text("想替换或补充品牌，把以品牌命名的透明底 PNG（如 Canon.png）放进 Logo 文件夹。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 小工具

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String = { String(format: "%.2f×", $0) }
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }

    /// 开关 ↔ 可选值：打开时写入默认值，关闭时清空。
    private func optionalBinding<Value>(
        _ keyPath: WritableKeyPath<RenderOptions, Value?>, default defaultValue: Value
    ) -> Binding<Bool> {
        Binding(
            get: { state.options[keyPath: keyPath] != nil },
            set: { state.options[keyPath: keyPath] = $0 ? defaultValue : nil }
        )
    }

    private func unwrapped<Value>(
        _ keyPath: WritableKeyPath<RenderOptions, Value?>, fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: { state.options[keyPath: keyPath] ?? fallback },
            set: { state.options[keyPath: keyPath] = $0 }
        )
    }
}
