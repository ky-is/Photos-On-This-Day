import MapKit
import Photos
import SwiftUI

/// Where the day's photos were taken, across every year it shows: a pin per place with the newest photo's thumbnail and
/// how many photos were taken there. Tapping a pin opens that photo in the viewer, among all of the day's photos.
struct DayMapView: View {
	/// The map's toggle in the toolbar and the menu bar: on until someone turns it off, then remembered between launches.
	static let visibleKey = "showsDayMap"

	let years: [PhotoYear]

	private var state = StateManager.shared

	init(years: [PhotoYear]) {
		self.years = years
	}

	private var dayAssets: [PHAsset] {
		years.flatMap(\.assets)
	}

	private var places: [MapPlace] {
		MapPlace.group(dayAssets) { $0.location?.coordinate }.map { MapPlace(assets: $0) }
	}

	var body: some View {
		Map(initialPosition: .automatic) {
			ForEach(places) { place in
				Annotation("", coordinate: place.coordinate, anchor: .bottom) {
					Button {
						state.openedPhoto = PhotoSelection(assets: dayAssets, selectedID: place.assets[0].localIdentifier)
					} label: {
						MapPin(place: place)
					}
						.buttonStyle(.plain)
						.accessibilityLabel(Text(place.accessibilityLabel))
						.accessibilityHint("Opens the photo")
				}
					.annotationTitles(.hidden)
			}
		}
			.mapStyle(.standard(pointsOfInterest: .excludingAll))
			.accessibilityLabel("Map of the day’s photos")
	}
}

extension View {
	/// The day's map pinned at the bottom while the photos scroll, with room under the last photos to scroll them clear
	/// of it.
	func dayMap(date: Date, years: [PhotoYear], isShown: Bool) -> some View {
		modifier(DayMapOverlay(date: date, years: years, isShown: isShown))
	}
}

private struct DayMapOverlay: ViewModifier {
	let date: Date
	let years: [PhotoYear]
	let isShown: Bool

	@Environment(\.screenSize) private var screenSize
	/// The home indicator's strip, which the map reaches past to sit an even inset from the screen's bottom edge.
	@State private var bottomSafeArea: CGFloat = 0

	func body(content: Content) -> some View {
		content
			// Room under the last photos for the map, which overlaps the home indicator's strip already set aside.
			.safeAreaInset(edge: .bottom, spacing: 0) {
				Color.clear
					.frame(height: isShown ? max(0, DayMapPanel.height(for: screenSize) + 2 * DayMapPanel.inset - bottomSafeArea) : 0)
			}
			// It's laid out from the screen's own edges, not the safe area's, so its bottom corners are concentric with the
			// display's: the full width of the screen, under the side safe areas too (iPad, iPhone on its side).
			.overlay(alignment: .bottom) {
				if isShown {
					DayMapPanel(date: date, years: years)
						.ignoresSafeArea(.container, edges: [.horizontal, .bottom])
						.transition(.move(edge: .bottom).combined(with: .opacity))
				}
			}
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.safeAreaInsets.bottom
			} action: { inset in
				bottomSafeArea = inset
			}
	}
}

/// The map pinned at the bottom of the day, an even inset from the screen's sides and bottom, with a handle to drag it up
/// to fill the screen below the toolbar and back down again (or tap it). Swiping it down from there hides it, like the
/// toolbar's map button: it squashes a little first, then slides off the bottom.
private struct DayMapPanel: View {
	/// Its gap from the screen's sides and bottom, and from the toolbar when it fills the screen.
	static let inset: CGFloat = 8
	/// How much of its usual height dragging it down takes off before it starts sliding away.
	private static let squashFraction = 0.4
	/// How far the handle has to be dragged, or flung, to expand or collapse it.
	private static let dragDistance: CGFloat = 60
	private static let flingDistance: CGFloat = 240

	/// Tall enough to read, short enough to leave plenty of the photos in view above it: its usual height.
	static func height(for screenSize: CGSize) -> CGFloat {
		min(300, max(200, screenSize.height * 0.28))
	}

	let date: Date
	let years: [PhotoYear]

	@Environment(\.screenSize) private var screenSize
	@AppStorage(DayMapView.visibleKey) private var showsMap = true
	@State private var expanded = false
	/// How far the handle has been dragged down (up is negative), springing back when let go.
	@GestureState(resetTransaction: Transaction(animation: .smooth)) private var drag: CGFloat = 0

	private var collapsed: CGFloat {
		Self.height(for: screenSize)
	}

	private var squash: CGFloat {
		collapsed * Self.squashFraction
	}

	var body: some View {
		GeometryReader { geometry in
			let full = max(collapsed, geometry.size.height - 2 * Self.inset)
			let height = (expanded ? full : collapsed) - drag
			DayMapView(years: years)
				.id(date)
				.frame(height: min(full, max(collapsed - squash, height)))
				.overlay(alignment: .top) {
					handle
				}
				.clipShape(ConcentricRectangle(uniformTopCorners: .fixed(28), uniformBottomCorners: .concentric(minimum: .fixed(28))))
				.shadow(color: .black.opacity(0.2), radius: 12, y: 4)
				.padding([.horizontal, .bottom], Self.inset)
				// Squashed as far as it goes, it follows the finger off the bottom of the screen.
				.offset(y: max(0, collapsed - squash - height))
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
		}
	}

	/// A grabber like a sheet's, on a strip wide enough to catch a thumb, leaving the rest of the map to pan.
	private var handle: some View {
		Capsule()
			.fill(.white.opacity(0.9))
			.frame(width: 36, height: 5)
			.shadow(color: .black.opacity(0.35), radius: 2)
			.frame(width: 120, height: 28)
			.contentShape(.rect)
			.gesture(DragGesture(coordinateSpace: .global)
				.updating($drag) { value, drag, _ in
					drag = value.translation.height
				}
				.onEnded { value in
					let moved = value.translation.height
					let flung = value.predictedEndTranslation.height
					withAnimation(.smooth) {
						if expanded, moved > Self.dragDistance || flung > Self.flingDistance {
							expanded = false
						} else if !expanded, moved > squash || flung > squash + Self.flingDistance {
							showsMap = false
						} else if !expanded, moved < -Self.dragDistance || flung < -Self.flingDistance {
							expanded = true
						}
					}
				})
			.onTapGesture {
				withAnimation(.smooth) {
					expanded.toggle()
				}
			}
			.accessibilityElement()
			.accessibilityLabel(expanded ? Text("Collapse Map") : Text("Expand Map"))
			.accessibilityAddTraits(.isButton)
			.accessibilityAction {
				withAnimation(.smooth) {
					expanded.toggle()
				}
			}
			.accessibilityAction(named: "Hide Map") {
				showsMap = false
			}
	}
}

/// Photos taken in about the same spot, newest year first, as one pin.
struct MapPlace: Identifiable {
	/// A thousandth of a degree of latitude and longitude, about 100 m.
	private struct Cell: Hashable {
		let latitude: Int
		let longitude: Int
	}

	let assets: [PHAsset]

	var id: String { assets[0].localIdentifier }

	var coordinate: CLLocationCoordinate2D {
		let coordinates = assets.compactMap { $0.location?.coordinate }
		let count = Double(max(1, coordinates.count))
		return CLLocationCoordinate2D(latitude: coordinates.map(\.latitude).reduce(0, +) / count, longitude: coordinates.map(\.longitude).reduce(0, +) / count)
	}

	var accessibilityLabel: String {
		let years = Set(assets.compactMap { $0.creationDate?.year }).sorted(by: >).map(String.init).joined(separator: ", ")
		return String(localized: "^[\(assets.count) photo](inflect: true)") + (years.isEmpty ? "" : ", \(years)")
	}

	/// Groups items taken within about 100 m of each other (the same thousandth of a degree), keeping their order.
	/// Items without a location are left out.
	static func group<Item>(_ items: [Item], coordinate: (Item) -> CLLocationCoordinate2D?) -> [[Item]] {
		var order: [Cell] = []
		var groups: [Cell: [Item]] = [:]
		for item in items {
			guard let location = coordinate(item), CLLocationCoordinate2DIsValid(location), location.latitude != 0 || location.longitude != 0 else { continue }
			let cell = Cell(latitude: Int((location.latitude * 1000).rounded()), longitude: Int((location.longitude * 1000).rounded()))
			if groups[cell] == nil {
				order.append(cell)
			}
			groups[cell, default: []].append(item)
		}
		return order.map { groups[$0]! }
	}
}

/// A photo's thumbnail in a white frame, with how many photos share the spot.
private struct MapPin: View {
	let place: MapPlace

	@Environment(\.displayScale) private var displayScale
	@Environment(\.thumbnailImageManager) private var imageManager
	@ScaledMetric(relativeTo: .body) private var side: CGFloat = 48
	@State private var image: PlatformImage?

	var body: some View {
		ZStack {
			if let image {
				Image(platformImage: image)
					.resizable()
					.aspectRatio(contentMode: .fill)
			} else {
				Color.secondary.opacity(0.3)
			}
		}
			.frame(width: side, height: side)
			.clipShape(.rect(cornerRadius: 8))
			.padding(3)
			.background(.white, in: .rect(cornerRadius: 11))
			.shadow(color: .black.opacity(0.3), radius: 4, y: 2)
			.overlay(alignment: .topTrailing) {
				if place.assets.count > 1 {
					Text(place.assets.count, format: .number)
						.font(.caption2.weight(.bold))
						.monospacedDigit()
						.foregroundStyle(.white)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(.tint, in: .capsule)
						.offset(x: 8, y: -8)
				}
			}
			.contentShape(.rect)
			.task(id: place.id) {
				let size = CGSize(width: side, height: side)
				for await result in imageManager.images(for: place.assets[0], size: size, scale: displayScale, cropped: true) {
					image = result.image
				}
			}
	}
}
