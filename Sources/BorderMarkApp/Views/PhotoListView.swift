import BorderMarkCore
import SwiftUI

struct PhotoListView: View {
    private static let thumbnailSide: CGFloat = 44

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if state.photos.isEmpty {
                emptyState
            } else {
                List(selection: $state.selectedPhotoID) {
                    ForEach(state.photos) { photo in
                        row(for: photo)
                            .tag(photo.id)
                            .contextMenu {
                                Button("移除", role: .destructive) { state.remove(photo) }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
            Divider()
            footer
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("还没有照片")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(for photo: PhotoItem) -> some View {
        HStack(spacing: 8) {
            thumbnail(for: photo)
            VStack(alignment: .leading, spacing: 2) {
                Text(photo.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(photo.metadata.model ?? "无 EXIF")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func thumbnail(for photo: PhotoItem) -> some View {
        if let image = photo.thumbnail {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: Self.thumbnailSide, height: Self.thumbnailSide)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary)
                .frame(width: Self.thumbnailSide, height: Self.thumbnailSide)
        }
    }

    private var footer: some View {
        HStack {
            Text(state.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button { state.removeAll() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(state.photos.isEmpty)
            .help("清空列表")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}
