import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset?
	var dayAssets: [PHAsset] = []
	let dateID: String
	let size: CGSize

	@Environment(\.displayScale) private var displayScale

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
						.overlay(alignment: .bottomTrailing) {
							HStack {
								Group {
									if asset.mediaType == .video {
										Text(Duration.seconds(asset.duration.rounded()), format: .time(pattern: .minuteSecond))
											.font(.caption.weight(.semibold).monospacedDigit())
										Image(systemName: "play.fill")
									} else if asset.mediaSubtypes.contains(.photoLive) {
										Image(systemName: "livephoto")
									}
									if asset.sourceType == .typeCloudShared {
										Image(systemName: "icloud")
									} else {
										PhotoFavoriteIcon(asset: asset)
									}
									if asset.mediaSubtypes.contains(.photoScreenshot) {
										Image(systemName: "iphone")
									}
								}
									.shadow(color: .black, radius: 1, x: 0, y: 0.5)
							}
								.padding(3)
								.foregroundStyle(.white)
						}
				}
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
					PhotoHideToggle(asset: asset, dateID: dateID)
				}
			}
	}
}

#Preview {
	PhotosYearThumbnail(asset: nil, dateID: "", size: CGSize(width: 128, height: 128))
}
