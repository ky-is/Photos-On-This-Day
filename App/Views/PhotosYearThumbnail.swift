import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset

	@State private var image: UIImage?

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				if let image = image {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: geometry.size.width, height: geometry.size.height)
						.clipped()
						.overlay(alignment: .bottomTrailing) {
							if asset.sourceType == .typeCloudShared {
								Image(systemName: "icloud")
									.foregroundColor(.white)
									.shadow(color: .black, radius: 1, x: 0, y: 0.5)
									.padding(2)
							}
						}
				}
			}
				.task {
					PHImageManager.default().requestImage(for: asset, targetSize: geometry.size, contentMode: .aspectFill, options: nil) { image, userInfo in
						DispatchQueue.main.async {
							self.image = image
						}
					}
				}
		}
	}
}

struct PhotosYearThumbnail_Previews: PreviewProvider {
	static var previews: some View {
		PhotosYearThumbnail(asset: PHAsset())
	}
}
