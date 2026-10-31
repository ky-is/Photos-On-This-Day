import Photos
import SwiftUI

struct PhotosYearThumbnail: View {
	let asset: PHAsset?
	var dayAssets: [PHAsset] = []
	let dateID: String
	let size: CGSize

	@Environment(\.displayScale) private var displayScale
	@Environment(\.photoTransition) private var photoTransition
	@Environment(\.isPinchingGrid) private var isPinchingGrid
	@Environment(\.thumbnailImageManager) private var imageManager
	@Environment(GridSelection.self) private var selection: GridSelection?

	@AppStorage(GridSelection.aspectRatioGridKey) private var showsAspectRatio = false
	@State private var image: PlatformImage?

	init(asset: PHAsset?, dayAssets: [PHAsset] = [], dateID: String, size: CGSize) {
		self.asset = asset
		self.dayAssets = dayAssets
		self.dateID = dateID
		self.size = size
	}

	var body: some View {
		Group {
			if let asset, let image {
				if let selection, selection.isSelecting {
					let isSelected = selection.contains(asset)
					Button {
						selection.toggle(asset)
					} label: {
						thumbnail(image, asset: asset)
							.overlay {
								if isSelected {
									Color.white.opacity(0.2)
								}
							}
							.overlay(alignment: .bottomTrailing) {
								if isSelected {
									Image(systemName: "checkmark.circle.fill")
										.font(.title3)
										.symbolRenderingMode(.palette)
										.foregroundStyle(.white, .tint)
										.padding(4)
								}
							}
					}
						.buttonStyle(.plain)
						.accessibilityAddTraits(isSelected ? .isSelected : [])
				} else {
					NavigationLink {
						PhotoViewer(selection: PhotoSelection(assets: dayAssets.isEmpty ? [asset] : dayAssets, selectedID: asset.localIdentifier), placeholder: image)
					} label: {
						thumbnail(image, asset: asset)
					}
						.pointerHighlight()
						.modifier(ZoomTransitionSource(id: asset.localIdentifier, namespace: photoTransition))
						// A pinch that starts on a photo shouldn't open it when the fingers lift.
						.disabled(isPinchingGrid)
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
			// On the loading placeholder too, so it reads as the photo rather than a "Photo" symbol.
			.modifier(ThumbnailAccessibility(asset: asset, dateID: dateID, isSelecting: selection?.isSelecting == true))
			.task(id: size) {
				guard let asset, size != .zero else { return }
				for await result in imageManager.images(for: asset, size: size, scale: displayScale, cropped: false) {
					image = result.image
				}
			}
			.contextMenu {
				if let asset, selection?.isSelecting != true {
					ShareLink(item: SharedAsset(asset: asset), preview: SharedAsset.preview(for: asset))
					PhotoFavoriteButton(asset: asset)
					PhotoHideToggle(asset: asset, dateID: dateID)
				}
			}
	}

	private func thumbnail(_ image: PlatformImage, asset: PHAsset) -> some View {
		Image(platformImage: image)
			.resizable()
			// The aspect ratio grid shows whole photos in their square, like the option in Photos.
			.aspectRatio(contentMode: showsAspectRatio ? .fit : .fill)
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

	/// What VoiceOver reads for a thumbnail: the kind of photo, when it was taken, and its badges.
	static func accessibilityDescription(of asset: PHAsset, isFavorite: Bool) -> Text {
		var parts: [Text] = []
		if asset.mediaType == .video {
			parts.append(Text("Video"))
			parts.append(Text(Duration.seconds(asset.duration.rounded()), format: .units(allowed: [.hours, .minutes, .seconds], width: .wide)))
		} else if asset.mediaSubtypes.contains(.photoLive) {
			parts.append(Text("Live Photo"))
		} else {
			parts.append(Text("Photo"))
		}
		if let date = asset.creationDate {
			parts.append(Text(date, format: .dateTime.year().month(.wide).day().hour().minute()))
		}
		if isFavorite {
			parts.append(Text("Favorite"))
		}
		if asset.sourceType == .typeCloudShared {
			parts.append(Text("iCloud Shared"))
		}
		return parts.dropFirst().reduce(parts[0]) { $0 + Text(verbatim: ", ") + $1 }
	}
}

extension EnvironmentValues {
	/// The grid's image manager, which prepares thumbnails near the screen ahead of time.
	@Entry var thumbnailImageManager: PHImageManager = .default()
}

/// Picking several photos to share or favorite at once, like Select in Photos.
@Observable final class GridSelection {
	private(set) var isSelecting = false
	/// In the order they were picked.
	private(set) var assets: [PHAsset] = []
	/// True while a finger slides across photos to select them, so the grid holds still.
	var isDragSelecting = false

	static let aspectRatioGridKey = "gridShowsAspectRatio"

	func contains(_ asset: PHAsset) -> Bool {
		assets.contains { $0.localIdentifier == asset.localIdentifier }
	}

	func toggle(_ asset: PHAsset) {
		if contains(asset) {
			assets.removeAll { $0.localIdentifier == asset.localIdentifier }
		} else {
			assets.append(asset)
		}
	}

	/// The selection as it was when a drag began, with the dragged-over photos added, or taken away when the drag began on a selected one.
	func apply(range: [PHAsset], selecting: Bool, to base: [PHAsset]) {
		let rangeIDs = Set(range.map(\.localIdentifier))
		assets = base.filter { !rangeIDs.contains($0.localIdentifier) } + (selecting ? range : [])
	}

	func start() {
		isSelecting = true
	}

	func end() {
		isSelecting = false
		assets = []
	}
}

/// What VoiceOver reads for a thumbnail, with the context menu's Favorite and Hide as actions, and zooming to resize the grid.
private struct ThumbnailAccessibility: ViewModifier {
	let asset: PHAsset?
	let dateID: String
	let isSelecting: Bool

	private var favorites = Favorites.shared
	private var filters = Filters.shared

	init(asset: PHAsset?, dateID: String, isSelecting: Bool) {
		self.asset = asset
		self.dateID = dateID
		self.isSelecting = isSelecting
	}

	func body(content: Content) -> some View {
		if let asset {
			let isFavorite = favorites.isFavorite(asset)
			content
				.accessibilityLabel(PhotosYearThumbnail.accessibilityDescription(of: asset, isFavorite: isFavorite))
				.accessibilityActions {
					if !isSelecting {
						if asset.sourceType == .typeUserLibrary {
							Button(isFavorite ? LocalizedStringKey("Unfavorite") : "Favorite") {
								Task {
									await favorites.toggle(asset)
								}
							}
						}
						Button("Hide from On This Day") {
							filters.setHidden(true, asset: asset, on: dateID)
						}
					}
				}
				// The grid's pinch to resize, for VoiceOver; zooming in shows bigger thumbnails.
				.accessibilityZoomAction { action in
					MenuActions.shared.columnStep = MenuActions.ColumnStep(change: action.direction == .zoomIn ? -1 : 1)
				}
		} else {
			content
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
