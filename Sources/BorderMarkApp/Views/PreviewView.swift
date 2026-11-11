import BorderMarkCore
import SwiftUI

struct PreviewView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                content
            }
            Divider()
            infoBar
        }
    }

    @ViewBuilder
    private var content: some View {
        if let preview = state.preview {
            Image(decorative: preview, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(28)
        } else if state.selectedPhoto != nil {
            ProgressView()
        } else {
            dropHint
        }
    }

    private var dropHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            Text("把照片或文件夹拖到这里")
                .font(.title3)
            Text("支持 JPEG、HEIC、PNG、TIFF 和常见 RAW")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("选择照片…") { state.presentImportPanel() }
                .controlSize(.large)
                .padding(.top, 4)
        }
    }

    private var infoBar: some View {
        HStack(spacing: 14) {
            if let photo = state.selectedPhoto {
                let resolver = PlaceholderResolver(metadata: photo.metadata, options: state.options)
                Text(resolver.resolve("{Model}") ?? "未读到机型")
                    .fontWeight(.medium)
                Text(resolver.resolve("{Params}") ?? "无拍摄参数，可在右侧手动填写")
                    .foregroundStyle(.secondary)
                Spacer()
                if let preview = state.preview {
                    Text("预览 \(preview.width)×\(preview.height)")
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(state.selectedTemplate.name)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}
