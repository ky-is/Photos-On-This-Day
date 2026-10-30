import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset?
	var dayAssets: [PHAsset] = []
	let dateID: String
	let size: CGSize

	@Environment(\.displayScale) private var displayScale
	@Environment(\.photoTransition) private var photoTransition

	@State private var image: UIImage?

	var body: some View {
		Group {
			if let asset, let image {
				NavigationLink {
					PhotoViewer(selection: PhotoSelection(assets: dayAssets.isEmpty ? [asset] : dayAssets, selectedID: asset.localIdentifier), placeholder: image)
				} label: {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: size.width, height: size.height)
						.overlay(alignment: .bottom) {
							// Favorite at the left and video length at the right, like in Photos.
							HStack {
								PhotoFavoriteIcon(asset: asset)
								Spacer()
								if asset.sourceType == .typeCloudShared {
									Image(systemName: "icloud")
								}
								if asset.mediaType == .video {
									Text(Duration.seconds(asset.duration.rounded()), format: .time(pattern: .minuteSecond))
								}
							}
								.font(.caption.weight(.semibold).monospacedDigit())
								.foregroundStyle(.white)
								.shadow(color: .black.opacity(0.6), radius: 2)
								.padding(4)
						}
				}
					.modifier(ZoomTransitionSource(id: asset.localIdentifier, namespace: photoTransition))
			} else {
				Image(systemName: "photo")
					.font(.system(size: 64, weight: .black))
					.foregroundStyle(.background)
					.frame(width: size.width, height: size.height)
					.background(Color.primary.opacity(0.05))
			}
		}
			.clipped()
			.task(id: size) {
				guard let asset, size != .zero else { return }
				for await result in PHImageManager.default().images(for: asset, size: size, scale: displayScale, cropped: false) {
					image = result.image
				}
			}
			.contextMenu {
				if let asset {
					ShareLink(item: SharedAsset(asset: asset), preview: SharedAsset.preview(for: asset))
					PhotoFavoriteButton(asset: asset)
					PhotoHideToggle(asset: asset, dateID: dateID)
				}
			}
	}
}

private struct ZoomTransitionSource: ViewModifier {
	let id: String
	let namespace: Namespace.ID?

	func body(content: Content) -> some View {
		if let namespace {
			content.matchedTransitionSource(id: id, in: namespace)
		} else {
			content
		}
	}
}

#Preview {
	PhotosYearThumbnail(asset: nil, dateID: "", size: CGSize(width: 128, height: 128))
}
