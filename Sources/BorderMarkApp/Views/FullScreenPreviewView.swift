import BorderMarkCore
import SwiftUI

/// 全屏预览：黑底铺满，只看成品。方向键或两侧按钮切换照片；单击或按 Z 在“适合屏幕”和 100% 像素之间切换；
/// 空格 / Esc / 右上角按钮退出。
struct FullScreenPreviewView: View {
    private static let chromePadding: CGFloat = 24
    private static let imagePadding: CGFloat = 48

    @EnvironmentObject private var state: AppState
    @State private var isChromeVisible = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            imageArea

            if state.photos.count > 1 {
                HStack {
                    navigationButton("chevron.left", label: "上一张") { state.selectPreviousPhoto() }
                    Spacer()
                    navigationButton("chevron.right", label: "下一张") { state.selectNextPhoto() }
                }
                .padding(.horizontal, Self.chromePadding)
                .opacity(isChromeVisible ? 1 : 0)
            }

            VStack {
                topBar
                Spacer()
                Text("← → ↑ ↓ 切换　单击或 Z 切换 100%　空格 / Esc 退出")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(Self.chromePadding)
            .opacity(isChromeVisible ? 1 : 0)
        }
        .onHover { isChromeVisible = $0 }
        .animation(.easeOut(duration: 0.2), value: isChromeVisible)
    }

    /// 显示原图画质的成品；还没渲染好时先显示快速预览并提示。100% 只在原图画质就绪后生效。
    @ViewBuilder
    private var imageArea: some View {
        if let image = state.displayPreview {
            let isActualSize = state.isActualSizePreview && state.isShowingFullResolution
            ZoomableImageView(
                image: image,
                isActualSize: isActualSize,
                onToggle: { _ in state.isActualSizePreview.toggle() }
            )
            .padding(isActualSize ? 0 : Self.imagePadding)
            .accessibilityLabel("全屏预览")
            if !state.isShowingFullResolution {
                Label("正在生成原图画质…", systemImage: "hourglass")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
            }
        } else {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        }
    }

    private var zoomButton: some View {
        Button { state.isActualSizePreview.toggle() } label: {
            Text(state.isActualSizePreview ? "适合屏幕" : "100%")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(state.isActualSizePreview ? "缩放到适合屏幕（Z）" : "按原图 100% 像素查看（Z）")
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            if let photo = state.selectedPhoto {
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.name)
                        .font(.headline)
                    if let index = state.selectedIndex {
                        Text("\(index + 1) / \(state.photos.count)　\(state.selectedTemplate.name)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .foregroundStyle(.white)
            }
            Spacer()
            zoomButton
            Button { state.exitFullScreenPreview() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .help("退出全屏预览（Esc）")
            .accessibilityLabel("退出全屏预览")
        }
    }

    private func navigationButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(label)
        .accessibilityLabel(label)
    }
}
