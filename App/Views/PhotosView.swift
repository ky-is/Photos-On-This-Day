import Photos
import SwiftUI

struct PhotoYear: Identifiable, Sendable {
	let year: Int
	let dateID: String
	let assets: [PHAsset]

	var id: Int { year }
}

extension EnvironmentValues {
	/// True while the grid is being pinched, and a moment after, so lifting the fingers doesn't open a photo.
	@Entry var isPinchingGrid = false
}

/// Where the grid sits in the main scroll view. A plain class, not state, so scrolling doesn't redraw anything.
final class ScrollTracker {
	/// Offsets are in the same terms as ScrollPosition.scrollTo(y:), which doesn't count the bars' inset.
	struct Metrics: Equatable {
		var contentOffsetY: CGFloat = 0
		/// The height of the scroll view between the bars.
		var visibleHeight: CGFloat = 0
		var maxOffsetY: CGFloat = 0

		init() {}

		init(_ geometry: ScrollGeometry) {
			contentOffsetY = geometry.contentOffset.y + geometry.contentInsets.top
			visibleHeight = geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
			maxOffsetY = max(0, geometry.contentSize.height - visibleHeight)
		}
	}

	var metrics = Metrics()
	var contentOffsetY: CGFloat { metrics.contentOffsetY }
	var visibleHeight: CGFloat { metrics.visibleHeight }
	/// The grid's frame in the scroll view's visible area.
	var gridFrame: CGRect = .zero
	/// Where the grid starts in the scrolled content, to place pinches caught by the whole screen.
	var gridOrigin: CGPoint = .zero
}

/// A pinch anywhere on the main screen, handed to the grid. Locations are in the scrolled content.
struct GridPinch: Equatable {
	static let coordinateSpace = "scrollContent"

	var startLocation: CGPoint
	var magnification: CGFloat
	var hasEnded = false
}

/// A finger sliding across photos in select mode: where it began, whether it selects or deselects, and what was selected before.
private struct DragSelection {
	let start: GridLayout.Position
	let selecting: Bool
	let base: [PHAsset]
	/// Where the finger is, from the top of the visible area, so the grid can scroll under a finger that holds still.
	var finger: CGPoint
}

/// The photo a pinch started on, so the grid can keep it under the fingers as the columns change.
private struct PinchAnchor {
	let position: GridLayout.Position
	/// Where the fingers were on the photo, in photo heights from its top.
	let fraction: CGFloat
	/// Where the fingers were on screen, from the top of the scroll view.
	let viewportY: CGFloat
	/// The grid's top in scrolled content, which column changes don't move.
	let gridTop: CGFloat
}

private struct FetchKey: Hashable {
	let date: Date
	let filters: PhotoFilters
	let libraryRevision: Int
}

private struct LoadedPhotos {
	let date: Date
	/// Past years with photos, newest first.
	let pastYears: [PhotoYear]
	/// This year's photos, shown only when no past years have any.
	let currentYear: PhotoYear?
}

struct PhotosView: View {
	let date: Date
	@Binding var scrollPosition: ScrollPosition
	let scrollTracker: ScrollTracker
	let viewerPhotoID: String?
	let pinch: GridPinch?

	private var state = StateManager.shared
	private var filters = Filters.shared

	@State private var loaded: LoadedPhotos?
	@AppStorage(PhotosYearView.thumbnailWidthKey) private var thumbnailWidth = PhotosYearView.defaultThumbnailWidth
	/// The pinch scale at the last column change, so each further step needs a fresh stretch.
	@State private var pinchBase: CGFloat = 1
	/// The direction of this pinch's last step: -1 fewer columns, 1 more, 0 none yet.
	@State private var lastStep = 0
	@State private var pinchAnchor: PinchAnchor?
	@State private var isPinching = false
	@State private var dragSelection: DragSelection?
	/// A drag that began up or down is a scroll, not a selection, until the finger lifts.
	@State private var isDragScrolling = false
	@State private var autoScroll: Task<Void, Never>?
	/// Prepares thumbnails a screen above and two below what's showing, so scrolling shows them sharp right away.
	@State private var thumbnailCache = PHCachingImageManager()
	@State private var cachedThumbnails: [PHAsset] = []
	@State private var cachedThumbnailSize = CGSize.zero

	@Environment(GridSelection.self) private var selection: GridSelection?
	/// Scales the grid with the fingers between column changes, so pinching feels continuous.
	@State private var liveScale: CGFloat = 1
	/// The point the grid scales around: where the fingers are, in the grid's own coordinates.
	@State private var scaleAnchor = CGPoint.zero

	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	init(date: Date, scrollPosition: Binding<ScrollPosition>, scrollTracker: ScrollTracker, viewerPhotoID: String? = nil, pinch: GridPinch? = nil) {
		self.pinch = pinch
		self.date = date
		_scrollPosition = scrollPosition
		self.scrollTracker = scrollTracker
		self.viewerPhotoID = viewerPhotoID
	}

	private var dateID: String { date.dateID }

	private var hiddenPhotosCount: Int {
		filters.hiddenPhotos[dateID]?.count ?? 0
	}

	var body: some View {
		VStack {
			if let loaded, loaded.date == date {
				if loaded.pastYears.isEmpty {
					noPastPhotos
					if let currentYear = loaded.currentYear {
						LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
							PhotosYearView(year: currentYear, dayAssets: currentYear.assets)
						}
					}
				} else {
					LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
						let dayAssets = loaded.pastYears.flatMap(\.assets)
						ForEach(loaded.pastYears) { year in
							PhotosYearView(year: year, dayAssets: dayAssets)
						}
					}
				}
				if hiddenPhotosCount > 0 {
					Button {
						filters.hiddenPhotos[dateID] = nil
					} label: {
						Text("Restore ^[\(hiddenPhotosCount) hidden photo](inflect: true)")
							.font(.title3)
							.padding(8)
					}
						.buttonStyle(.bordered)
						.padding(.top)
				}
			} else {
				ProgressView()
					.padding()
			}
		}
			.padding(.bottom, 32)
			// Scale around the fingers. Drawing only, so the grid's layout and scrolling stay put.
			.scaleEffect(liveScale, anchor: .topLeading)
			.offset(x: scaleAnchor.x * (1 - liveScale), y: scaleAnchor.y * (1 - liveScale))
			.onGeometryChange(for: CGRect.self) { proxy in
				proxy.frame(in: .scrollView)
			} action: { [scrollTracker] frame in
				scrollTracker.gridFrame = frame
			}
			.onGeometryChange(for: CGPoint.self) { proxy in
				proxy.frame(in: .named(GridPinch.coordinateSpace)).origin
			} action: { [scrollTracker] origin in
				scrollTracker.gridOrigin = origin
			}
			// In select mode, slide across photos to select them all, like in Photos.
			.simultaneousGesture(DragGesture(minimumDistance: 10)
				.onChanged(dragChanged)
				.onEnded { _ in
					dragSelection = nil
					isDragScrolling = false
					autoScroll?.cancel()
					autoScroll = nil
					selection?.isDragSelecting = false
				}, isEnabled: selection?.isSelecting == true)
			// Pinch anywhere on the screen to show bigger or smaller thumbnails, like in Photos.
			.onChange(of: pinch) { _, pinch in
				guard let pinch else { return }
				if pinch.hasEnded {
					pinchEnded()
				} else {
					pinchChanged(pinch)
				}
			}
			.environment(\.isPinchingGrid, isPinching)
			.environment(\.thumbnailImageManager, thumbnailCache)
			// Every 200pt scrolled, or when the photos or their size change, move the preloaded window along.
			.onGeometryChange(for: Int.self) { proxy in
				Int(proxy.frame(in: .scrollView).minY / 200)
			} action: { _ in
				cacheNearbyThumbnails()
			}
			.onChange(of: columns) {
				cacheNearbyThumbnails()
			}
			.onChange(of: loaded?.pastYears.count) {
				cacheNearbyThumbnails()
			}
			.onDisappear {
				thumbnailCache.stopCachingImagesForAllAssets()
			}
			.onChange(of: viewerPhotoID) { _, id in
				if let id {
					reveal(id)
				}
			}
			.screenshotSupport()
			.task(id: FetchKey(date: date, filters: filters.photoFilters(for: dateID), libraryRevision: state.libraryRevision)) {
				let photos = await Self.load(date: date, filters: filters.photoFilters(for: dateID))
				if !Task.isCancelled {
					loaded = photos
				}
			}
	}

	private func dragChanged(_ value: DragGesture.Value) {
		guard let selection, let years = loaded?.pastYears, !isDragScrolling else { return }
		let layout = layout()
		if dragSelection == nil {
			// Only a sideways start selects; up and down still scrolls.
			guard abs(value.translation.width) > abs(value.translation.height) else {
				isDragScrolling = true
				return
			}
			guard let start = layout.position(at: value.startLocation) else { return }
			dragSelection = DragSelection(start: start, selecting: !selection.contains(years[start.year].assets[start.index]), base: selection.assets, finger: .zero)
			selection.isDragSelecting = true
			autoScroll = Task {
				while !Task.isCancelled {
					try? await Task.sleep(for: .milliseconds(16))
					autoScrollStep()
				}
			}
		}
		dragSelection?.finger = CGPoint(x: value.location.x, y: scrollTracker.gridFrame.minY + value.location.y)
		selectToFinger()
	}

	private func cacheNearbyThumbnails() {
		guard let years = loaded?.pastYears, scrollTracker.visibleHeight > 0 else { return }
		let layout = layout()
		let size = CGSize(width: layout.cellSide, height: layout.cellSide)
		if size != cachedThumbnailSize {
			thumbnailCache.stopCachingImagesForAllAssets()
			cachedThumbnails = []
			cachedThumbnailSize = size
		}
		let visibleTop = -scrollTracker.gridFrame.minY
		let height = scrollTracker.visibleHeight
		guard let first = layout.position(at: CGPoint(x: 0, y: visibleTop - height)), let last = layout.position(at: CGPoint(x: layout.width, y: visibleTop + 2 * height)) else { return }
		let wanted = layout.positions(from: first, to: last).map { years[$0.year].assets[$0.index] }
		thumbnailCache.setCaching(false, cachedThumbnails.filter { !wanted.contains($0) }, size: size, scale: displayScale, contentMode: .aspectFill)
		thumbnailCache.setCaching(true, wanted.filter { !cachedThumbnails.contains($0) }, size: size, scale: displayScale, contentMode: .aspectFill)
		cachedThumbnails = wanted
	}

	/// Selects from where the drag began to the photo under the finger.
	private func selectToFinger() {
		guard let selection, let years = loaded?.pastYears, let dragSelection else { return }
		let layout = layout()
		let point = CGPoint(x: dragSelection.finger.x, y: dragSelection.finger.y - scrollTracker.gridFrame.minY)
		guard let end = layout.position(at: point) else { return }
		let range = layout.positions(from: dragSelection.start, to: end).map { years[$0.year].assets[$0.index] }
		selection.apply(range: range, selecting: dragSelection.selecting, to: dragSelection.base)
	}

	/// With the finger near the top or bottom while drag-selecting, scrolls that way, faster the closer it gets, like in Photos.
	private func autoScrollStep() {
		guard let finger = dragSelection?.finger else { return }
		let metrics = scrollTracker.metrics
		let zone: CGFloat = 80
		let speed: CGFloat
		if finger.y < zone {
			speed = -min(1, (zone - finger.y) / zone) * 14
		} else if finger.y > metrics.visibleHeight - zone {
			speed = min(1, (finger.y - (metrics.visibleHeight - zone)) / zone) * 14
		} else {
			return
		}
		let offset = min(max(0, metrics.contentOffsetY + speed), metrics.maxOffsetY)
		guard offset != metrics.contentOffsetY else { return }
		scrollPosition.scrollTo(y: offset)
		selectToFinger()
	}

	private func pinchChanged(_ pinch: GridPinch) {
		if !isPinching {
			isPinching = true
			let origin = scrollTracker.gridOrigin
			startPinch(at: CGPoint(x: pinch.startLocation.x - origin.x, y: pinch.startLocation.y - origin.y))
		}
		var stretch = pinch.magnification / pinchBase
		// Stepping back the way the pinch just came takes a bigger stretch, so a small wobble doesn't flip between two sizes.
		let biggerAt: CGFloat = lastStep == 1 ? 1.5 : 1.3
		let smallerAt: CGFloat = lastStep == -1 ? 0.67 : 0.77
		if stretch > biggerAt || stretch < smallerAt {
			let step = stretch > 1 ? -1 : 1
			if let ratio = changeColumns(by: step) {
				// The new layout is `ratio` times bigger, so scale it back to keep the photos the size the fingers made them.
				pinchBase *= ratio
				stretch = pinch.magnification / pinchBase
				lastStep = step
			}
		}
		// Follow the fingers up to the next step; past the last one, only give a little.
		let range: ClosedRange<CGFloat> = canChangeColumns(by: stretch > 1 ? -1 : 1) ? smallerAt...biggerAt : 0.95...1.05
		liveScale = reduceMotion ? 1 : min(max(stretch, range.lowerBound), range.upperBound)
	}

	private func pinchEnded() {
		pinchBase = 1
		lastStep = 0
		pinchAnchor = nil
		Task {
			// The thumbnail's tap lands as the fingers lift, just after this.
			try? await Task.sleep(for: .milliseconds(300))
			isPinching = false
		}
		withAnimation(reduceMotion ? nil : .snappy) {
			liveScale = 1
		}
	}

	private var columns: Int {
		GridLayout.columns(width: screenSize.width, thumbnailWidth: thumbnailWidth)
	}

	private func layout(columns: Int? = nil) -> GridLayout {
		GridLayout(width: scrollTracker.gridFrame.width, columns: columns ?? self.columns, yearCounts: loaded?.pastYears.map(\.assets.count) ?? [])
	}

	private func canChangeColumns(by change: Int) -> Bool {
		GridLayout.columnRange.contains(columns + change)
	}

	/// Steps the columns at once, keeping the pinched photo under the fingers. Returns how much bigger the photos got, or nil if nothing changed.
	private func changeColumns(by change: Int) -> CGFloat? {
		guard canChangeColumns(by: change) else { return nil }
		let old = layout()
		let new = layout(columns: old.columns + change)
		// No animation: sliding every photo to its new spot while also scrolling is what made it fly around.
		var transaction = Transaction()
		transaction.disablesAnimations = true
		withTransaction(transaction) {
			thumbnailWidth = GridLayout.thumbnailWidth(columns: new.columns, width: screenSize.width)
			if let pinchAnchor {
				let fingerY = new.top(of: pinchAnchor.position) + pinchAnchor.fraction * new.cellSide
				scaleAnchor.y = fingerY
				scrollPosition.scrollTo(y: pinchAnchor.gridTop + fingerY - pinchAnchor.viewportY)
			}
		}
		return new.cellSide / old.cellSide
	}

	/// Scrolls the grid, out of sight behind the viewer, so the viewer's photo is on screen to close back to, like in Photos.
	private func reveal(_ id: String) {
		guard let years = loaded?.pastYears else { return }
		for (yearIndex, year) in years.enumerated() {
			guard let index = year.assets.firstIndex(where: { $0.localIdentifier == id }) else { continue }
			let layout = layout()
			// Where the photo is now, measured from the top of the visible area.
			let top = scrollTracker.gridFrame.minY + layout.top(of: GridLayout.Position(year: yearIndex, index: index))
			// The year's label pins over the top of the visible area, so the photo needs to be below it.
			if top < GridLayout.headerHeight || top + layout.cellSide > scrollTracker.visibleHeight {
				scrollPosition.scrollTo(y: max(0, scrollTracker.contentOffsetY + top + layout.cellSide / 2 - scrollTracker.visibleHeight / 2))
			}
			return
		}
	}

	private func startPinch(at point: CGPoint) {
		let frame = scrollTracker.gridFrame
		scaleAnchor = point
		let layout = layout()
		guard let position = layout.position(at: point) else { return }
		pinchAnchor = PinchAnchor(position: position, fraction: (point.y - layout.top(of: position)) / layout.cellSide, viewportY: frame.minY + point.y, gridTop: scrollTracker.contentOffsetY + frame.minY)
	}

	private var noPastPhotos: some View {
		VStack {
			Group {
				Text("No photos from past years on this day")
					.font(.title3.weight(.medium))
					.padding(.vertical)
					.foregroundStyle(.secondary)
				if !filters.showShared {
					Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
						.foregroundStyle(.secondary)
				} else {
					Text("You can browse other days\nusing the ◀︎ and ▶︎ buttons")
						.foregroundStyle(.secondary)
					Button {
						Task {
							await state.scanForDayWithPhotos()
						}
					} label: {
						if state.isScanning {
							ProgressView()
						} else {
							Text("Find recent day with photos")
						}
					}
						.buttonStyle(.bordered)
						.disabled(state.isScanning)
				}
			}
				.fixedSize(horizontal: false, vertical: true)
		}
			.multilineTextAlignment(.center)
			.frame(maxWidth: 512)
			.padding()
	}

	@concurrent private static func load(date: Date, filters: PhotoFilters) async -> LoadedPhotos {
		let dateID = date.dateID
		let byYearsBack = PHAsset.assetsByYearsBack(Array(0...maxYearsBack), from: date, filters: filters)
		let pastYears = byYearsBack
			.filter { $0.key > 0 }
			.sorted { $0.key < $1.key }
			.map { PhotoYear(year: date.year - $0.key, dateID: dateID, assets: $0.value) }
		let currentYear = pastYears.isEmpty ? byYearsBack[0].map { PhotoYear(year: date.year, dateID: dateID, assets: $0) } : nil
		return LoadedPhotos(date: date, pastYears: pastYears, currentYear: currentYear)
	}
}

#Preview {
	PhotosView(date: Date.current(), scrollPosition: .constant(ScrollPosition()), scrollTracker: ScrollTracker())
		.environment(GridSelection())
		.environment(\.screenSize, CGSize(width: 390, height: 844))
}
