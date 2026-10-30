import AVKit
import MapKit
import Photos
import PhotosUI
import SwiftUI
import os

/// The photos of a day, opened at one of them. Used for navigation and widget deep links.
struct PhotoSelection: Hashable, Identifiable {
	let assets: [PHAsset]
	let selectedID: String

	var id: String { selectedID }
}

/// Full screen photos for a day: swipe between them, zoom stills, play videos and Live Photos.
struct PhotoViewer: View {
	let assets: [PHAsset]
	/// The thumbnail already loaded for the opened photo, shown until a sharper image loads.
	let placeholder: UIImage?

	@State private var selectedID: String?
	@State private var fullQualityImages: [String: UIImage] = [:]
	@State private var locationDescription: String?

	@Environment(\.dismiss) private var dismiss

	init(selection: PhotoSelection, placeholder: UIImage? = nil) {
		assets = selection.assets
		self.placeholder = placeholder
		_selectedID = State(initialValue: selection.selectedID)
	}

	private var selectedAsset: PHAsset? {
		assets.first { $0.localIdentifier == selectedID }
	}

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: 0) {
				ForEach(assets, id: \.localIdentifier) { asset in
					PhotoPage(asset: asset, placeholder: asset.localIdentifier == selectedID ? placeholder : nil, isSelected: asset.localIdentifier == selectedID) { image in
						fullQualityImages[asset.localIdentifier] = image
					}
						.containerRelativeFrame([.horizontal, .vertical])
				}
			}
				.scrollTargetLayout()
		}
			.scrollTargetBehavior(.paging)
			.scrollPosition(id: $selectedID)
			.scrollIndicators(.hidden)
			.ignoresSafeArea()
			.background(.background)
			.toolbar {
				ToolbarItemGroup(placement: .topBarLeading) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.left")
							.font(.body.bold())
							.modifier(ToolbarButtonContentModifier())
					}
						.accessibilityLabel("Back")
				}
				ToolbarItemGroup(placement: .topBarTrailing) {
					if let selectedID, let image = fullQualityImages[selectedID] {
						ShareLink(item: Image(uiImage: image), preview: SharePreview("Photo", image: Image(uiImage: image))) {
							Label("Share", systemImage: "square.and.arrow.up")
								.modifier(ToolbarButtonContentModifier())
						}
					}
					if let selectedAsset {
						PhotoFavoriteButton(asset: selectedAsset)
					}
				}
				ToolbarItem(placement: .principal) {
					VStack {
						if let locationDescription {
							Text(locationDescription)
								.font(.caption.bold())
								.fixedSize(horizontal: true, vertical: false)
						}
						if let date = selectedAsset?.creationDate {
							Text(date, format: .dateTime)
								.font(.caption2)
						}
					}
				}
			}
			.navigationBarBackButtonHidden(true)
			.navigationBarTitleDisplayMode(.inline)
			.task(id: selectedID) {
				locationDescription = nil
				locationDescription = await Self.describeLocation(of: selectedAsset)
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

/// One page of the viewer: a zoomable still, a video, or a Live Photo.
private struct PhotoPage: View {
	let asset: PHAsset
	let placeholder: UIImage?
	let isSelected: Bool
	let onFullQuality: (UIImage) -> Void

	@State private var image: UIImage?
	@State private var isZoomed = false

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	private var isPhone: Bool {
		UIDevice.current.userInterfaceIdiom == .phone
	}

	var body: some View {
		Group {
			if asset.mediaType == .video {
				VideoPage(asset: asset, isSelected: isSelected)
			} else if asset.mediaSubtypes.contains(.photoLive) {
				LivePhotoPage(asset: asset, size: screenSize, placeholder: image ?? placeholder)
			} else {
				GeometryReader { geometry in
					ZoomScrollView(onZoom: { isZoomed = $0 > 1.2 }) {
						if let shown = image ?? placeholder {
							Image(uiImage: shown)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.padding(.top, isPhone ? -geometry.safeAreaInsets.top : nil)
								.padding(.bottom, isPhone ? geometry.safeAreaInsets.bottom : nil)
						}
					}
				}
			}
		}
			.task {
				for await result in PHImageManager.default().images(for: asset, size: screenSize, scale: displayScale, cropped: false) {
					image = rotatedForPhone(result.image)
					if !result.isDegraded {
						onFullQuality(result.image)
					}
				}
			}
			.task(id: isZoomed) {
				// Load a sharper image the first time the photo is zoomed in.
				guard isZoomed, asset.mediaType == .image else { return }
				let longestSide = Double(max(asset.pixelWidth, asset.pixelHeight))
				let fit = min(1, 4096 / longestSide)
				let size = CGSize(width: Double(asset.pixelWidth) * fit, height: Double(asset.pixelHeight) * fit)
				if let sharp = await PHImageManager.default().image(for: asset, size: size, scale: 1, cropped: false) {
					image = rotatedForPhone(sharp)
				}
			}
	}

	/// Shows landscape stills sideways on iPhone, so they fill the portrait screen.
	private func rotatedForPhone(_ image: UIImage) -> UIImage {
		guard isPhone, asset.mediaType == .image, !asset.mediaSubtypes.contains(.photoLive), image.size.width > image.size.height, let cgImage = image.cgImage else { return image }
		return UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
	}
}

private struct VideoPage: View {
	let asset: PHAsset
	let isSelected: Bool

	@State private var player: AVPlayer?

	var body: some View {
		ZStack {
			ProgressView()
			if let player {
				VideoPlayer(player: player)
			}
		}
			.task {
				guard let item = await PHImageManager.default().playerItem(for: asset) else { return }
				player = AVPlayer(playerItem: item.value)
				if isSelected {
					player?.play()
				}
			}
			.onChange(of: isSelected) { _, isSelected in
				if isSelected {
					player?.play()
				} else {
					player?.pause()
				}
			}
			.onDisappear {
				player?.pause()
			}
	}
}

/// Touch and hold to play, like in Photos.
private struct LivePhotoPage: View {
	let asset: PHAsset
	let size: CGSize
	let placeholder: UIImage?

	@State private var livePhoto: PHLivePhoto?

	@Environment(\.displayScale) private var displayScale

	var body: some View {
		ZStack(alignment: .topLeading) {
			if let livePhoto {
				LivePhotoView(livePhoto: livePhoto)
			} else if let placeholder {
				Image(uiImage: placeholder)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			Label("Live", systemImage: "livephoto")
				.font(.caption.bold())
				.padding(6)
				.background(.thinMaterial, in: .capsule)
				.padding()
				.padding(.top, 96)
		}
			.task {
				let target = CGSize(width: size.width * displayScale, height: size.height * displayScale)
				livePhoto = await PHImageManager.default().livePhoto(for: asset, targetSize: target)?.value
			}
	}
}

private struct LivePhotoView: UIViewRepresentable {
	let livePhoto: PHLivePhoto

	func makeUIView(context: Context) -> PHLivePhotoView {
		let view = PHLivePhotoView()
		view.contentMode = .scaleAspectFit
		return view
	}

	func updateUIView(_ view: PHLivePhotoView, context: Context) {
		view.livePhoto = livePhoto
	}
}

/// Holds a value that Photos hands back on its own queue.
struct PhotosResult<Value>: @unchecked Sendable {
	let value: Value
}

extension PHImageManager {
	func playerItem(for asset: PHAsset) async -> PhotosResult<AVPlayerItem>? {
		let options = PHVideoRequestOptions()
		options.isNetworkAccessAllowed = true
		options.deliveryMode = .automatic
		return await withCheckedContinuation { continuation in
			requestPlayerItem(forVideo: asset, options: options) { item, _ in
				continuation.resume(returning: item.map(PhotosResult.init))
			}
		}
	}

	/// The final Live Photo; Photos may first deliver a lower quality one, which is skipped.
	func livePhoto(for asset: PHAsset, targetSize: CGSize) async -> PhotosResult<PHLivePhoto>? {
		let options = PHLivePhotoRequestOptions()
		options.isNetworkAccessAllowed = true
		options.deliveryMode = .highQualityFormat
		return await withCheckedContinuation { continuation in
			requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { livePhoto, _ in
				continuation.resume(returning: livePhoto.map(PhotosResult.init))
			}
		}
	}
}
