import AVKit
import MapKit
import Photos
import PhotosUI
import SwiftUI
import WidgetKit
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
	let placeholder: PlatformImage?

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
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

	init(selection: PhotoSelection, placeholder: PlatformImage? = nil) {
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
				// Arrow keys page through the photos and Escape closes, from a hardware keyboard. ⌘L hides and ⌘⌫ deletes, like the More menu.
				Group {
					KeyboardShortcutButton(.leftArrow) { step(by: -1) }
					KeyboardShortcutButton(.rightArrow) { step(by: 1) }
					KeyboardShortcutButton(.escape) { dismiss() }
					if let selectedAsset {
						KeyboardShortcutButton("l", modifiers: .command) { hide(selectedAsset) }
						if selectedAsset.sourceType == .typeUserLibrary {
							KeyboardShortcutButton(.delete, modifiers: .command) {
								Task {
									await delete(selectedAsset)
								}
							}
						}
					}
				}
					.hidden()
					.accessibilityHidden(true)
			}
			.onDisappear {
				imageCache.stopCachingImagesForAllAssets()
			}
			// The two-finger scrub closes, like Back.
			.accessibilityAction(.escape) {
				dismiss()
			}
			// VoiceOver keeps the bars showing, so Back, Share, Favorite and Info stay reachable.
			.onChange(of: voiceOverEnabled, initial: true) { _, isOn in
				if isOn {
					showsChrome = true
				}
			}
			.background(showsChrome ? AnyShapeStyle(.background) : AnyShapeStyle(.black))
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
			.barsVisibility(showsChrome)
			.hidesSystemOverlays(!showsChrome)
			.toolbar {
				ToolbarItem(placement: .leadingBar) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "chevron.left")
							.font(.body.bold())
							.modifier(ToolbarButtonContentModifier())
					}
						.accessibilityLabel("Back")
				}
				ToolbarItem(placement: .trailingBar) {
					if let selectedAsset {
						Menu {
							Button("Hide from On This Day", systemImage: "eye.slash") {
								hide(selectedAsset)
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
				ToolbarItemGroup(placement: .bottomActions) {
					if let selectedAsset {
						ShareLink(item: SharedAsset(asset: selectedAsset), preview: SharedAsset.preview(for: selectedAsset))
						Spacer()
						PhotoFavoriteButton(asset: selectedAsset)
							.keyboardShortcut(".", modifiers: [])
						Button("Info", systemImage: "info.circle") {
							showsInfo = true
						}
							.keyboardShortcut("i", modifiers: .command)
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
			.inlineNavigationTitle()
			// Reduce Motion opens with a plain push instead of the zoom.
			.modifier(ZoomTransition(sourceID: selectedID, namespace: reduceMotion ? nil : photoTransition))
			.task(id: selectedID) {
				locationDescription = nil
				locationDescription = await Self.describeLocation(of: selectedAsset)
			}
	}

	private func hide(_ asset: PHAsset) {
		Filters.shared.setHidden(true, asset: asset, on: StateManager.shared.date.dateID)
		remove(asset)
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
		withAnimation(reduceMotion ? nil : .default) {
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
			// So a widget isn't left showing it.
			WidgetCenter.shared.reloadAllTimelines()
		} catch {
			// Also where it lands when the delete isn't confirmed.
			logger.info("Delete not done: \(error.localizedDescription)")
		}
	}

	private func step(by change: Int) {
		guard let index = assets.firstIndex(where: { $0.localIdentifier == selectedID }), assets.indices.contains(index + change) else { return }
		withAnimation(reduceMotion ? nil : .default) {
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

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	/// A short sheet for just the date and place, taller when the text is large enough to need it.
	private var detents: Set<PresentationDetent> {
		asset.location != nil || dynamicTypeSize.isAccessibilitySize ? [.medium, .large] : [.height(120)]
	}

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
					Marker(place ?? asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "", coordinate: coordinate)
				}
					.clipShape(.rect(cornerRadius: 16))
					.padding(.top, 8)
			}
		}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding()
			.padding(.top, 8)
			.presentationDetents(detents)
	}
}

/// Small thumbnails of the day's photos: drag to skim through them, or tap one to jump to it, like in Photos.
private struct PhotoScrubber: View {
	let assets: [PHAsset]
	@Binding var selectedID: String?

	/// The strip's own position, so dragging it and paging the photos don't fight over the selection.
	@State private var scrubbedID: String?
	@State private var isScrubbing = false
	/// The strip's own width: less than the screen's where bars sit beside it, like the iPhone Duo cover screen's side rail.
	@State private var width: CGFloat = 0

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

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
						.accessibilityLabel(PhotosYearThumbnail.accessibilityDescription(of: asset, isFavorite: Favorites.shared.isFavorite(asset)))
						.accessibilityAddTraits(isSelected ? .isSelected : [])
				}
			}
				.frame(height: 48)
				.scrollTargetLayout()
		}
			// Lets the first and last photos reach the middle.
			.contentMargins(.horizontal, max(0, (width - Self.itemWidth) / 2), for: .scrollContent)
			// Kept to its own frame, inside the safe area, rather than scrolling under bars at the sides
			.clipped()
			.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
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
					withAnimation(reduceMotion ? nil : .snappy) {
						scrubbedID = id
					}
				}
			}
			.padding(.bottom, 8)
	}
}

private struct ScrubberThumbnail: View {
	let asset: PHAsset

	@State private var image: PlatformImage?

	@Environment(\.displayScale) private var displayScale

	var body: some View {
		Color.secondary.opacity(0.2)
			.overlay {
				if let image {
					Image(platformImage: image)
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
	let modifiers: EventModifiers
	let action: () -> Void

	init(_ key: KeyEquivalent, modifiers: EventModifiers = [], action: @escaping () -> Void) {
		self.key = key
		self.modifiers = modifiers
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			EmptyView()
		}
			.keyboardShortcut(key, modifiers: modifiers)
	}
}

/// Zooms in from the tapped thumbnail, and back out to the current photo's thumbnail when closed or swiped down.
private struct ZoomTransition: ViewModifier {
	let sourceID: String?
	let namespace: Namespace.ID?

	func body(content: Content) -> some View {
		#if os(iOS)
		if let namespace {
			content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
		} else {
			content
		}
		#else
		// The Mac has no zoom navigation transition.
		content
		#endif
	}
}

/// One page of the viewer: a zoomable still or Live Photo, or a video.
private struct PhotoPage: View {
	let asset: PHAsset
	let placeholder: PlatformImage?
	let isSelected: Bool
	let imageManager: PHImageManager
	@Binding var showsChrome: Bool

	/// Fit, not fill: a landscape photo on a portrait screen needs only the pixels that show.
	static let contentMode = PHImageContentMode.aspectFit

	@State private var image: PlatformImage?
	@State private var isZoomed = false
	/// VoiceOver's zoom steps, passed on to the scroll view.
	@State private var zoomStep: ZoomStep?
	/// Counts VoiceOver's requests to play the Live Photo.
	@State private var livePlayCount = 0

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

	private var isLive: Bool {
		asset.mediaSubtypes.contains(.photoLive)
	}

	private var accessibilityDescription: Text {
		PhotosYearThumbnail.accessibilityDescription(of: asset, isFavorite: Favorites.shared.isFavorite(asset))
	}

	var body: some View {
		Group {
			if asset.mediaType == .video {
				VideoPage(asset: asset, isSelected: isSelected)
					// Keeps the player's controls reachable inside.
					.accessibilityElement(children: .contain)
					.accessibilityLabel(accessibilityDescription)
			} else {
				ZoomScrollView(zoomStep: zoomStep) { zoomed in
					isZoomed = zoomed
					// Zooming in clears the screen for the photo, and zooming back out brings the bars back, like in Photos. Not with VoiceOver, which needs the bars.
					withAnimation {
						showsChrome = !zoomed || voiceOverEnabled
					}
				} onTap: {
					guard !voiceOverEnabled else { return }
					withAnimation {
						showsChrome.toggle()
					}
				} onPinchClose: {
					dismiss()
				} content: {
					ZStack {
						if let shown = image ?? placeholder {
							Image(platformImage: shown)
								.resizable()
								.aspectRatio(contentMode: .fit)
						}
						// Zoomed in, the sharper still shows instead of the screen-sized Live Photo.
						if isLive, !isZoomed {
							LivePhotoLayer(asset: asset, playsHint: isSelected, playCount: livePlayCount)
						}
					}
				}
					.accessibilityElement(children: .ignore)
					.accessibilityLabel(accessibilityDescription)
					.accessibilityAddTraits(.isImage)
					.accessibilityZoomAction { action in
						zoomStep = ZoomStep(zoomsIn: action.direction == .zoomIn)
					}
					.accessibilityActions {
						if isLive, !isZoomed {
							Button("Play Live Photo") {
								livePlayCount += 1
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

#if os(macOS)
/// AppKit's player view, with the usual controls. SwiftUI's VideoPlayer crashes on the Mac.
private struct MacVideoPlayer: NSViewRepresentable {
	let player: AVPlayer

	func makeNSView(context: Context) -> AVPlayerView {
		let view = AVPlayerView()
		view.controlsStyle = .inline
		view.player = player
		return view
	}

	func updateNSView(_ view: AVPlayerView, context: Context) {
		view.player = player
	}
}
#endif

private struct VideoPage: View {
	let asset: PHAsset
	let isSelected: Bool

	@State private var player: AVPlayer?

	var body: some View {
		ZStack {
			if let player {
				#if os(macOS)
				MacVideoPlayer(player: player)
				#else
				VideoPlayer(player: player)
				#endif
			} else {
				ProgressView()
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
	/// Plays the whole Live Photo each time this goes up.
	let playCount: Int

	@State private var livePhoto: PHLivePhoto?

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	var body: some View {
		Group {
			if let livePhoto {
				LivePhotoView(livePhoto: livePhoto, playsHint: playsHint, playCount: playCount)
			}
		}
			.task {
				let target = CGSize(width: screenSize.width * displayScale, height: screenSize.height * displayScale)
				livePhoto = await PHImageManager.default().livePhoto(for: asset, targetSize: target)?.value
			}
	}
}

#if os(iOS)
private typealias PlatformViewRepresentable = UIViewRepresentable
#else
private typealias PlatformViewRepresentable = NSViewRepresentable
#endif

private struct LivePhotoView: PlatformViewRepresentable {
	let livePhoto: PHLivePhoto
	/// Plays the short preview once each time the photo becomes the current one.
	let playsHint: Bool
	/// Plays the whole Live Photo each time this goes up, for VoiceOver's action.
	let playCount: Int

	final class Coordinator {
		var hasPlayedHint = false
		var playedCount: Int

		init(playedCount: Int) {
			self.playedCount = playedCount
		}
	}

	func makeCoordinator() -> Coordinator {
		// Counts from now, so a view made again doesn't replay an earlier request.
		Coordinator(playedCount: playCount)
	}

	#if os(iOS)
	func makeUIView(context: Context) -> PHLivePhotoView {
		let view = PHLivePhotoView()
		view.contentMode = .scaleAspectFit
		return view
	}

	func updateUIView(_ view: PHLivePhotoView, context: Context) {
		update(view, context: context)
	}
	#else
	func makeNSView(context: Context) -> PHLivePhotoView {
		let view = PHLivePhotoView()
		view.contentMode = .aspectFit
		return view
	}

	func updateNSView(_ view: PHLivePhotoView, context: Context) {
		update(view, context: context)
	}
	#endif

	private func update(_ view: PHLivePhotoView, context: Context) {
		if view.livePhoto !== livePhoto {
			view.livePhoto = livePhoto
		}
		if playsHint, !context.coordinator.hasPlayedHint, !context.environment.accessibilityReduceMotion {
			context.coordinator.hasPlayedHint = true
			view.startPlayback(with: .hint)
		} else if !playsHint {
			context.coordinator.hasPlayedHint = false
		}
		if playCount != context.coordinator.playedCount {
			context.coordinator.playedCount = playCount
			view.startPlayback(with: .full)
		}
	}
}
