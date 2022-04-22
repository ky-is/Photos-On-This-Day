import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset
	let size: CGSize

	@State private var image: UIImage?

	var body: some View {
		ZStack {
			Group {
				if let image = image {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: size.width, height: size.height)
						.overlay(alignment: .bottomTrailing) {
							if asset.sourceType == .typeCloudShared {
								Image(systemName: "icloud")
									.foregroundColor(.white)
									.shadow(color: .black, radius: 1, x: 0, y: 0.5)
									.padding(2)
							}
						}
				} else {
					Image(systemName: "photo")
						.font(.system(size: 32))
						.foregroundColor(.secondary)
				}
			}
				.clipped()
		}
			.task {
				PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: nil) { image, userInfo in
					DispatchQueue.main.async {
						self.image = image
					}
				}
			}
	}
}

struct PhotosYearThumbnail_Previews: PreviewProvider {
	static var previews: some View {
		PhotosYearThumbnail(asset: PHAsset(), size: CGSize(width: 128, height: 128))
	}
}
