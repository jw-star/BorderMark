import BorderMarkCore
import SwiftUI

/// “Logo”页：来源与样式、颜色、Logo 文件。
struct LogoSettingsView: View {
    private enum LogoColorMode: String, CaseIterable, Identifiable {
        case followText = "跟随文字"
        case custom = "自定义"
        case original = "原色"

        var id: String { rawValue }
    }

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard("品牌 Logo", systemImage: "seal") {
                Toggle("显示品牌 Logo", isOn: $state.options.isLogoVisible)
                if !state.selectedTemplate.hasLogo {
                    Label("“\(state.selectedTemplate.name)”没有 Logo 位置，这里的设置在该模式下看不到效果。",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    sourceMenu
                    variantPicker
                }
                .disabled(!state.options.isLogoVisible)
            }

            SettingsCard("颜色", systemImage: "paintpalette") {
                Picker("Logo 颜色", selection: logoColorMode) {
                    ForEach(LogoColorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if let color = state.options.logoColor, state.options.isLogoTinted {
                    ColorPicker("自定义颜色", selection: Binding(
                        get: { Color(hex: color) },
                        set: { state.options.logoColor = $0.hexString }
                    ), supportsOpacity: false)
                }
                HintText("“原色”保留图片本身的颜色，彩色 Logo 用它；另外两项只对透明底的 Logo 生效。")
            }
            .disabled(!state.options.isLogoVisible)

            SettingsCard("Logo 文件", systemImage: "folder") {
                HStack {
                    Button("选择图片…") { state.presentLogoPanel() }
                    if state.customLogoName != nil {
                        Button("移除自选") { state.clearCustomLogo() }
                    }
                    Spacer()
                    Button("打开文件夹") { state.revealLogosFolder() }
                    Button { state.reloadLogos() } label: { Image(systemName: "arrow.clockwise") }
                        .help("重新加载 Logo 库")
                        .accessibilityLabel("重新加载 Logo 库")
                }
                .controlSize(.small)
                HintText("文件名 Nikon.png 是品牌的默认 Logo，Nikon-黄标.png 这样加后缀的是其他样式。同名文件会替换内置的。")
            }
        }
    }

    // MARK: - 来源

    private var sourceMenu: some View {
        LabeledContent("来源") {
            Menu(sourceTitle) {
                choiceItem("自动匹配相机品牌", isSelected: state.logoChoice == .auto) { state.logoChoice = .auto }
                choiceItem("仅品牌名文字", isSelected: state.logoChoice == .text) { state.logoChoice = .text }
                if let name = state.customLogoName {
                    choiceItem("自选：\(name)", isSelected: state.logoChoice == .custom) { state.logoChoice = .custom }
                }
                Divider()
                ForEach(state.logoBrands) { brand in
                    brandItem(brand)
                }
            }
            .fixedSize()
        }
    }

    /// 只有一种样式的品牌直接是菜单项，多种样式的品牌展开成子菜单。
    @ViewBuilder
    private func brandItem(_ brand: LogoBrand) -> some View {
        let isBrandSelected = state.logoChoice == .brand(brand.id)
        let variants = state.availableVariants(for: brand)
        if variants.count == 1 {
            choiceItem(brand.name, isSelected: isBrandSelected) { state.chooseBrandLogo(variants[0]) }
        } else {
            Menu(brand.name) {
                ForEach(variants) { entry in
                    let isSelected = isBrandSelected && state.preferredEntry(for: brand).id == entry.id
                    choiceItem(entry.variantName, isSelected: isSelected) { state.chooseBrandLogo(entry) }
                }
            }
        }
    }

    private func choiceItem(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Toggle(title, isOn: Binding(get: { isSelected }, set: { _ in action() }))
    }

    private var sourceTitle: String {
        switch state.logoChoice {
        case .auto: return "自动匹配相机品牌"
        case .text: return "仅品牌名文字"
        case .custom: return "自选：\(state.customLogoName ?? "")"
        case .brand(let id): return state.logoBrands.first { $0.id == id }?.name ?? id
        }
    }

    // MARK: - 样式

    /// 当前照片对应品牌的样式。选择会记在这个品牌上，以后自动匹配到它都用这个样式。
    @ViewBuilder
    private var variantPicker: some View {
        if let brand = state.currentLogoBrand {
            let variants = state.availableVariants(for: brand)
            if variants.count > 1 {
                Picker("\(brand.name) 样式", selection: Binding(
                    get: { state.preferredEntry(for: brand).id },
                    set: { id in
                        if let entry = variants.first(where: { $0.id == id }) { state.setPreferredVariant(entry) }
                    }
                )) {
                    ForEach(variants) { Text($0.variantName).tag($0.id) }
                }
                HintText(state.isLogoOriginalColor
                    ? "原色模式下默认用彩色样式。每个品牌选的样式会记住，批量导出时不同相机各用各的。"
                    : "彩色样式在下方“颜色”选“原色”后可选。每个品牌选的样式会记住。")
            } else {
                HintText(brand.variants.count > variants.count
                    ? "\(brand.name) 的彩色样式在下方“颜色”选“原色”后可用。"
                    : "当前品牌 \(brand.name) 只有一种样式。")
            }
        } else if state.logoChoice == .auto, state.selectedPhoto != nil {
            HintText("当前照片的品牌没有对应的 Logo 图片，会用品牌名文字代替。")
        }
    }

    // MARK: - 颜色

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
}
