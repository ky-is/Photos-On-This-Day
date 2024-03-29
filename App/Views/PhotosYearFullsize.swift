import Photos
import SwiftUI

struct PhotosYearFullsize: View {
	let asset: PHAsset
	@State var image: UIImage

	init(asset: PHAsset, image: UIImage) {
		self.asset = asset
		self._image = State(initialValue: image)
	}

	@State private var fullQualityImage: UIImage?
	@State private var locationDescription: String? = "..."

	@Environment(\.dismiss) private var dismiss
	@Environment(\.screenSize) private var screenSize

	var body: some View {
		GeometryReader { geometry in
			ZoomScrollView {
				let shouldInset = UIDevice.current.userInterfaceIdiom == .phone
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.padding(.top, shouldInset ? -geometry.safeAreaInsets.top : nil)
					.padding(.bottom, shouldInset ? geometry.safeAreaInsets.bottom : nil)
			}
				.edgesIgnoringSafeArea(.all)
		}
			.toolbar {
				ToolbarItemGroup(placement: .navigationBarLeading) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.left")
							.font(.body.bold())
							.modifier(ToolbarButtonContentModifier())
					}
				}
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					ShareImageButton(image: fullQualityImage ?? image)
						.disabled(fullQualityImage == nil)
					PhotoFavoriteButton(asset: asset)
				}
				ToolbarItem(placement: .principal) {
					VStack {
						if let locationDescription = locationDescription {
							Text(locationDescription)
								.font(.system(.caption, design: .rounded).bold())
								.fixedSize(horizontal: true, vertical: false)
						}
						if let date = asset.creationDate {
							Text(date, format: .dateTime)
								.font(.system(.caption2, design: .rounded))
						}
					}
//						.frame(maxWidth: .greatestFiniteMagnitude)
				}
			}
			.navigationBarBackButtonHidden(true)
			.navigationBarTitleDisplayMode(.inline)
			.task {
				PHImageManager.default().requestImage(for: asset, size: screenSize, isSynchronous: false, cropped: false) { loadedImage, userInfo in
					if let loadedImage = loadedImage {
						let rotatedImage = UIDevice.current.userInterfaceIdiom == .phone && loadedImage.size.width > loadedImage.size.height ? UIImage(cgImage: loadedImage.cgImage!, scale:1, orientation: UIImage.Orientation.right) : loadedImage
						DispatchQueue.main.async {
							image = rotatedImage
							let isDegraded = userInfo?[PHImageResultIsDegradedKey] as? Bool
							if isDegraded == nil || isDegraded == false {
								fullQualityImage = loadedImage
							}
						}
						if let location = asset.location {
							CLGeocoder().reverseGeocodeLocation(location) { (placemarks, error) in
								DispatchQueue.main.async {
									guard let placemark = placemarks?.first else {
										locationDescription = nil
										return
									}
									locationDescription = [placemark.thoroughfare, placemark.subLocality, placemark.locality, placemark.subAdministrativeArea, placemark.administrativeArea]
										.compactMap({ $0 })
										.prefix(2)
										.joined(separator: ", ")
								}
							}
						} else {
							DispatchQueue.main.async {
								locationDescription = nil
							}
						}
					}
				}
			}
	}
}

struct PhotosYearFullsize_Previews: PreviewProvider {
	static var previews: some View {
		PhotosYearFullsize(asset: PHAsset(), image: UIImage())
	}
}
