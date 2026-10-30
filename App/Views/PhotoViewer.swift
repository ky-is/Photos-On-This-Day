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
	/// Hiding or deleting a photo takes it out of here too.
	@State private var assets: [PHAsset]
	/// The thumbnail already loaded for the opened photo, shown until a sharper image loads.
	let placeholder: UIImage?

	@State private var selectedID: String?
	@State private var showsChrome = true
	@State private var showsInfo = false
	/// Prepares the photos on either side of the current one, so swiping to them shows them sharp right away.
	@State private var imageCache = PHCachingImageManager()
	@State private var cachedAssets: [PHAsset] = []
	@State private var locationDescription: String?

	@Environment(\.dismiss) private var dismiss
	@Environment(\.photoTransition) private var photoTransition
	@Environment(\.viewerShowsPhoto) private var viewerShowsPhoto
	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	init(selection: PhotoSelection, placeholder: UIImage? = nil) {
		_assets = State(initialValue: selection.assets)
		self.placeholder = placeholder
		_selectedID = State(initialValue: selection.selectedID)
	}

	private var selectedAsset: PHAsset? {
		assets.first { $0.localIdentifier == selectedID }
	}

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.horizontal) {
				LazyHStack(spacing: 0) {
					ForEach(assets, id: \.localIdentifier) { asset in
						PhotoPage(asset: asset, placeholder: asset.localIdentifier == selectedID ? placeholder : nil, isSelected: asset.localIdentifier == selectedID, imageManager: imageCache, showsChrome: $showsChrome)
							.containerRelativeFrame([.horizontal, .vertical])
					}
				}
					.scrollTargetLayout()
			}
				.scrollTargetBehavior(.paging)
				.scrollPosition(id: $selectedID)
				.scrollIndicators(.hidden)
				.ignoresSafeArea()
				.onChange(of: selectedID, initial: true) { _, id in
					guard let id else { return }
					// Jumps from the scrubber can land on pages the lazy stack hasn't made yet, which only scrollTo reaches.
					proxy.scrollTo(id)
					cacheNeighbors()
					viewerShowsPhoto(id)
				}
		}
			.background {
				// Arrow keys page through the photos and Escape closes, from a hardware keyboard.
				Group {
					KeyboardShortcutButton(.leftArrow) { step(by: -1) }
					KeyboardShortcutButton(.rightArrow) { step(by: 1) }
					KeyboardShortcutButton(.escape) { dismiss() }
				}
					.hidden()
					.accessibilityHidden(true)
			}
			.onDisappear {
				imageCache.stopCachingImagesForAllAssets()
			}
			.background(showsChrome ? Color(.systemBackground) : .black)
			.safeAreaInset(edge: .bottom) {
				if showsChrome && assets.count > 1 {
					PhotoScrubber(assets: assets, selectedID: $selectedID)
				}
			}
			.overlay(alignment: .topLeading) {
				if showsChrome, let selectedAsset, selectedAsset.mediaSubtypes.contains(.photoLive) {
					Label("Live", systemImage: "livephoto")
						.font(.caption.bold())
						.padding(6)
						.background(.thinMaterial, in: .capsule)
						.padding()
				}
			}
			.toolbarVisibility(showsChrome ? .visible : .hidden, for: .navigationBar, .bottomBar)
			.statusBarHidden(!showsChrome)
			.persistentSystemOverlays(showsChrome ? .automatic : .hidden)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.left")
							.font(.body.bold())
							.modifier(ToolbarButtonContentModifier())
					}
						.accessibilityLabel("Back")
				}
				ToolbarItem(placement: .topBarTrailing) {
					if let selectedAsset {
						Menu {
							Button("Hide from On This Day", systemImage: "eye.slash") {
								Filters.shared.setHidden(true, asset: selectedAsset, on: StateManager.shared.date.dateID)
								remove(selectedAsset)
							}
							if selectedAsset.sourceType == .typeUserLibrary {
								Button("Delete", systemImage: "trash", role: .destructive) {
									Task {
										await delete(selectedAsset)
									}
								}
							}
						} label: {
							Label("More", systemImage: "ellipsis")
								.modifier(ToolbarButtonContentModifier())
						}
					}
				}
				ToolbarItemGroup(placement: .bottomBar) {
					if let selectedAsset {
						ShareLink(item: SharedAsset(asset: selectedAsset), preview: SharedAsset.preview(for: selectedAsset))
						Spacer()
						PhotoFavoriteButton(asset: selectedAsset)
						Button("Info", systemImage: "info.circle") {
							showsInfo = true
						}
					}
				}
			}
			.sheet(isPresented: $showsInfo) {
				if let selectedAsset {
					PhotoInfo(asset: selectedAsset, place: locationDescription)
				}
			}
			.navigationTitle(title)
			.navigationSubtitle(subtitle)
			.navigationBarBackButtonHidden(true)
			.navigationBarTitleDisplayMode(.inline)
			.modifier(ZoomTransition(sourceID: selectedID, namespace: photoTransition))
			.task(id: selectedID) {
				locationDescription = nil
				locationDescription = await Self.describeLocation(of: selectedAsset)
			}
	}

	/// Moves to the next photo, or the one before at the end, and takes this one out; closes when none are left.
	private func remove(_ asset: PHAsset) {
		guard let index = assets.firstIndex(of: asset) else { return }
		let neighbor = assets.indices.contains(index + 1) ? index + 1 : index - 1
		guard assets.indices.contains(neighbor) else {
			dismiss()
			return
		}
		selectedID = assets[neighbor].localIdentifier
		withAnimation {
			_ = assets.remove(at: index)
		}
	}

	/// Moves the photo to Recently Deleted. Photos asks to confirm first, like deleting in Photos.
	private func delete(_ asset: PHAsset) async {
		do {
			try await PHPhotoLibrary.shared().performChanges(onAssetsWith: [asset.localIdentifier]) { assets in
				PHAssetChangeRequest.deleteAssets(assets)
			}
			remove(asset)
		} catch {
			// Also where it lands when the delete isn't confirmed.
			logger.info("Delete not done: \(error.localizedDescription)")
		}
	}

	private func step(by change: Int) {
		guard let index = assets.firstIndex(where: { $0.localIdentifier == selectedID }), assets.indices.contains(index + change) else { return }
		withAnimation {
			selectedID = assets[index + change].localIdentifier
		}
	}

	/// Keeps the two photos on each side of the current one prepared, and lets go of the rest.
	private func cacheNeighbors() {
		guard let index = assets.firstIndex(where: { $0.localIdentifier == selectedID }) else { return }
		let neighbors = Array(assets[max(0, index - 2)...min(assets.count - 1, index + 2)]).filter { $0.mediaType == .image }
		imageCache.setCaching(false, cachedAssets.filter { !neighbors.contains($0) }, size: screenSize, scale: displayScale, contentMode: PhotoPage.contentMode)
		imageCache.setCaching(true, neighbors.filter { !cachedAssets.contains($0) }, size: screenSize, scale: displayScale, contentMode: PhotoPage.contentMode)
		cachedAssets = neighbors
	}

	/// The place, or the date when there's no place, like in Photos.
	private var title: Text {
		if let locationDescription {
			Text(locationDescription)
		} else if let date = selectedAsset?.creationDate {
			Text(date, format: .dateTime.year().month().day())
		} else {
			Text(verbatim: "")
		}
	}

	private var subtitle: Text {
		guard let date = selectedAsset?.creationDate else { return Text(verbatim: "") }
		return locationDescription == nil ? Text(date, format: .dateTime.hour().minute()) : Text(date, format: .dateTime)
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

/// When and where a photo was taken, with a map, like Photos' info panel.
private struct PhotoInfo: View {
	let asset: PHAsset
	let place: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let date = asset.creationDate {
				Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
					.font(.headline)
			}
			if let place {
				Text(place)
					.foregroundStyle(.secondary)
			}
			if let coordinate = asset.location?.coordinate {
				Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))) {
					Marker(place ?? "", coordinate: coordinate)
				}
					.clipShape(.rect(cornerRadius: 16))
					.padding(.top, 8)
			}
		}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding()
			.padding(.top, 8)
			.presentationDetents(asset.location == nil ? [.height(120)] : [.medium, .large])
	}
}

/// Small thumbnails of the day's photos: drag to skim through them, or tap one to jump to it, like in Photos.
private struct PhotoScrubber: View {
	let assets: [PHAsset]
	@Binding var selectedID: String?

	/// The strip's own position, so dragging it and paging the photos don't fight over the selection.
	@State private var scrubbedID: String?
	@State private var isScrubbing = false

	@Environment(\.screenSize) private var screenSize

	private static let itemWidth: CGFloat = 32

	var body: some View {
		ScrollView(.horizontal) {
			LazyHStack(spacing: 2) {
				ForEach(assets, id: \.localIdentifier) { asset in
					let isSelected = asset.localIdentifier == selectedID
					Button {
						selectedID = asset.localIdentifier
					} label: {
						ScrubberThumbnail(asset: asset)
							.frame(width: Self.itemWidth, height: isSelected ? 48 : 40)
							.clipShape(.rect(cornerRadius: 3))
					}
						.buttonStyle(.plain)
						.accessibilityLabel(Text(asset.creationDate ?? .now, format: .dateTime))
				}
			}
				.frame(height: 48)
				.scrollTargetLayout()
		}
			// Lets the first and last photos reach the middle.
			.contentMargins(.horizontal, max(0, (screenSize.width - Self.itemWidth) / 2), for: .scrollContent)
			.scrollTargetBehavior(.viewAligned)
			.scrollPosition(id: $scrubbedID)
			.scrollIndicators(.hidden)
			.onScrollPhaseChange { _, phase in
				isScrubbing = phase != .idle
			}
			.onChange(of: scrubbedID) { _, id in
				if isScrubbing {
					selectedID = id
				}
			}
			.onChange(of: selectedID, initial: true) { _, id in
				if !isScrubbing {
					withAnimation(.snappy) {
						scrubbedID = id
					}
				}
			}
			.padding(.bottom, 8)
	}
}

private struct ScrubberThumbnail: View {
	let asset: PHAsset

	@State private var image: UIImage?

	@Environment(\.displayScale) private var displayScale

	var body: some View {
		Color.secondary.opacity(0.2)
			.overlay {
				if let image {
					Image(uiImage: image)
						.resizable()
						.aspectRatio(contentMode: .fill)
				}
			}
			.task {
				for await result in PHImageManager.default().images(for: asset, size: CGSize(width: 48, height: 48), scale: displayScale, cropped: false) {
					image = result.image
				}
			}
	}
}

/// A button with no look, there only for its keyboard shortcut.
private struct KeyboardShortcutButton: View {
	let key: KeyEquivalent
	let action: () -> Void

	init(_ key: KeyEquivalent, action: @escaping () -> Void) {
		self.key = key
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			EmptyView()
		}
			.keyboardShortcut(key, modifiers: [])
	}
}

/// Zooms in from the tapped thumbnail, and back out to the current photo's thumbnail when closed or swiped down.
private struct ZoomTransition: ViewModifier {
	let sourceID: String?
	let namespace: Namespace.ID?

	func body(content: Content) -> some View {
		if let namespace {
			content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
		} else {
			content
		}
	}
}

/// One page of the viewer: a zoomable still or Live Photo, or a video.
private struct PhotoPage: View {
	let asset: PHAsset
	let placeholder: UIImage?
	let isSelected: Bool
	let imageManager: PHImageManager
	@Binding var showsChrome: Bool

	/// Fit, not fill: a landscape photo on a portrait screen needs only the pixels that show.
	static let contentMode = PHImageContentMode.aspectFit

	@State private var image: UIImage?
	@State private var isZoomed = false

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		Group {
			if asset.mediaType == .video {
				VideoPage(asset: asset, isSelected: isSelected)
			} else {
				ZoomScrollView { zoomed in
					isZoomed = zoomed
					// Zooming in clears the screen for the photo, and zooming back out brings the bars back, like in Photos.
					withAnimation {
						showsChrome = !zoomed
					}
				} onTap: {
					withAnimation {
						showsChrome.toggle()
					}
				} onPinchClose: {
					dismiss()
				} content: {
					ZStack {
						if let shown = image ?? placeholder {
							Image(uiImage: shown)
								.resizable()
								.aspectRatio(contentMode: .fit)
						}
						// Zoomed in, the sharper still shows instead of the screen-sized Live Photo.
						if asset.mediaSubtypes.contains(.photoLive), !isZoomed {
							LivePhotoLayer(asset: asset, playsHint: isSelected)
						}
					}
				}
			}
		}
			.task(id: screenSize) {
				for await result in imageManager.images(for: asset, size: screenSize, scale: displayScale, cropped: false, contentMode: Self.contentMode) {
					// Photos' quick low-quality image can be blurrier than the thumbnail already showing.
					if !result.isDegraded || (image == nil && placeholder == nil) {
						image = result.image
					}
				}
			}
			.task(id: isZoomed) {
				// Load a sharper image the first time the photo is zoomed in.
				guard isZoomed, asset.mediaType == .image else { return }
				let longestSide = Double(max(asset.pixelWidth, asset.pixelHeight))
				let fit = min(1, 4096 / longestSide)
				let size = CGSize(width: Double(asset.pixelWidth) * fit, height: Double(asset.pixelHeight) * fit)
				if let sharp = await imageManager.image(for: asset, size: size, scale: 1, cropped: false) {
					image = sharp
				}
			}
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

/// Covers the still once the Live Photo loads: a moment of motion on arriving, then touch and hold to play it all, like in Photos.
private struct LivePhotoLayer: View {
	let asset: PHAsset
	let playsHint: Bool

	@State private var livePhoto: PHLivePhoto?

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	var body: some View {
		Group {
			if let livePhoto {
				LivePhotoView(livePhoto: livePhoto, playsHint: playsHint)
			}
		}
			.task {
				let target = CGSize(width: screenSize.width * displayScale, height: screenSize.height * displayScale)
				livePhoto = await PHImageManager.default().livePhoto(for: asset, targetSize: target)?.value
			}
	}
}

private struct LivePhotoView: UIViewRepresentable {
	let livePhoto: PHLivePhoto
	/// Plays the short preview once each time the photo becomes the current one.
	let playsHint: Bool

	final class Coordinator {
		var hasPlayedHint = false
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	func makeUIView(context: Context) -> PHLivePhotoView {
		let view = PHLivePhotoView()
		view.contentMode = .scaleAspectFit
		return view
	}

	func updateUIView(_ view: PHLivePhotoView, context: Context) {
		if view.livePhoto !== livePhoto {
			view.livePhoto = livePhoto
		}
		if playsHint, !context.coordinator.hasPlayedHint, !context.environment.accessibilityReduceMotion {
			context.coordinator.hasPlayedHint = true
			view.startPlayback(with: .hint)
		} else if !playsHint {
			context.coordinator.hasPlayedHint = false
		}
	}
}
