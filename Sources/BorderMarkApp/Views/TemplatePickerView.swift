import BorderMarkCore
import SwiftUI

struct TemplatePickerView: View {
    private static let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private static let cardHeight: CGFloat = 96

    @EnvironmentObject private var state: AppState

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 10) {
            ForEach(state.templates) { template in
                card(for: template)
            }
        }
    }

    private func card(for template: Template) -> some View {
        let isSelected = template.id == state.selectedTemplateID
        return Button {
            state.selectedTemplateID = template.id
        } label: {
            VStack(spacing: 5) {
                thumbnail(for: template)
                    .frame(height: Self.cardHeight)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                          lineWidth: isSelected ? 2 : 1)
                    )
                Text(template.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help(template.summary)
        .accessibilityLabel("\(template.name)，\(template.summary)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func thumbnail(for template: Template) -> some View {
        if let image = state.templateThumbnails[template.id] {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .padding(6)
        } else {
            TemplateGlyph(template: template)
                .padding(12)
        }
    }
}

/// 还没有照片时的示意图：按模板的边框比例画一个小版式。
private struct TemplateGlyph: View {
    let template: Template

    var body: some View {
        GeometryReader { proxy in
            let layout = CanvasLayout(photoSize: CGSize(width: 300, height: 200), border: template.border)
            let scale = min(proxy.size.width / layout.canvasSize.width, proxy.size.height / layout.canvasSize.height)
            let canvas = CGSize(width: layout.canvasSize.width * scale, height: layout.canvasSize.height * scale)

            ZStack(alignment: .topLeading) {
                Rectangle().fill(backgroundFill)
                Rectangle()
                    .fill(Color.gray.opacity(0.45))
                    .frame(width: layout.photoRect.width * scale, height: layout.photoRect.height * scale)
                    .offset(x: layout.photoRect.minX * scale, y: layout.photoRect.minY * scale)
            }
            .frame(width: canvas.width, height: canvas.height)
            .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.12)))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private var backgroundFill: Color {
        switch template.background {
        case .solid(let color): return Color(hex: color)
        case .gradient(let from, _): return Color(hex: from)
        case .blur, .dominant: return Color.gray.opacity(0.75)
        }
    }
}
