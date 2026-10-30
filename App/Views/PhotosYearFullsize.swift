import MapKit
import Photos
import SwiftUI
import os

struct PhotosYearFullsize: View {
	let asset: PHAsset?

	@State private var image: UIImage
	@State private var fullQualityImage: UIImage?
	@State private var locationDescription: String? = "..."

	@Environment(\.dismiss) private var dismiss
	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	init(asset: PHAsset?, image: UIImage) {
		self.asset = asset
		_image = State(initialValue: image)
	}

	private var isPhone: Bool {
		UIDevice.current.userInterfaceIdiom == .phone
	}

	var body: some View {
		GeometryReader { geometry in
			ZoomScrollView {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.padding(.top, isPhone ? -geometry.safeAreaInsets.top : nil)
					.padding(.bottom, isPhone ? geometry.safeAreaInsets.bottom : nil)
			}
				.ignoresSafeArea()
		}
			.toolbar {
				ToolbarItemGroup(placement: .topBarLeading) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.left")
							.font(.body.bold())
							.modifier(ToolbarButtonContentModifier())
					}
				}
				ToolbarItemGroup(placement: .topBarTrailing) {
					let shareImage = fullQualityImage ?? image
					ShareLink(item: Image(uiImage: shareImage), preview: SharePreview("Photo", image: Image(uiImage: shareImage))) {
						Label("Share", systemImage: "square.and.arrow.up")
							.modifier(ToolbarButtonContentModifier())
					}
						.disabled(fullQualityImage == nil)
					if let asset {
						PhotoFavoriteButton(asset: asset)
					}
				}
				ToolbarItem(placement: .principal) {
					VStack {
						if let locationDescription {
							Text(locationDescription)
								.font(.caption.bold())
								.fixedSize(horizontal: true, vertical: false)
						}
						if let date = asset?.creationDate {
							Text(date, format: .dateTime)
								.font(.caption2)
						}
					}
				}
			}
			.navigationBarBackButtonHidden(true)
			.navigationBarTitleDisplayMode(.inline)
			.task {
				guard let asset else { return }
				for await result in PHImageManager.default().images(for: asset, size: screenSize, scale: displayScale, cropped: false) {
					let loaded = result.image
					if isPhone, loaded.size.width > loaded.size.height, let cgImage = loaded.cgImage {
						// Fill the portrait screen with landscape photos.
						image = UIImage(cgImage: cgImage, scale: loaded.scale, orientation: .right)
					} else {
						image = loaded
					}
					if !result.isDegraded {
						fullQualityImage = loaded
					}
				}
			}
			.task {
				locationDescription = await Self.describeLocation(of: asset)
			}
	}

	private static func describeLocation(of asset: PHAsset?) async -> String? {
		guard let location = asset?.location, let request = MKReverseGeocodingRequest(location: location) else { return nil }
		do {
			let mapItem = try await request.mapItems.first
			return mapItem?.addressRepresentations?.cityWithContext ?? mapItem?.address?.shortAddress
		} catch {
			logger.error("Reverse geocode failed: \(error.localizedDescription)")
			return nil
		}
	}
}

#Preview {
	PhotosYearFullsize(asset: nil, image: UIImage())
}
