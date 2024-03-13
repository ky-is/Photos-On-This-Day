import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset?
	let dateID: String
	let size: CGSize

	@State private var image: UIImage?

	var body: some View {
		ZStack {
			Group {
				if let asset, let image {
					NavigationLink {
						PhotosYearFullsize(asset: asset, image: image)
					} label: {
						Image(uiImage: image)
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: size.width, height: size.height)
							.overlay(alignment: .bottomTrailing) {
								HStack {
									Group {
										if asset.sourceType == .typeCloudShared {
											Image(systemName: "icloud") // rectangle.stack.badge.person.crop
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
		}
#if !targetEnvironment(simulator)
			.task {
				guard let asset else { return }
				PHCachingImageManager.default().requestImage(for: asset, size: size, isSynchronous: false, cropped: true) { image, userInfo in
					Task { @MainActor in
						self.image = image
					}
				}
			}
#endif
			.contextMenu {
				if let asset {
//					PhotoFavoriteToggle(asset: asset) //TODO doesn't work??
					PhotoHideToggle(asset: asset, dateID: dateID)
				}
			}
	}
}

#Preview {
	PhotosYearThumbnail(asset: nil, dateID: "", size: CGSize(width: 128, height: 128))
}
