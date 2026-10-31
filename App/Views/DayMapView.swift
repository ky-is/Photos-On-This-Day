import MapKit
import Photos
import SwiftUI

/// Where the day's photos were taken, across every year it shows: a pin per place with the newest photo's thumbnail and
/// how many photos were taken there. Tapping a pin opens that photo in the viewer, among all of the day's photos.
struct DayMapView: View {
	/// The map's toggle in the toolbar and the menu bar, remembered between launches.
	static let visibleKey = "showsDayMap"

	/// Tall enough to read, short enough to leave plenty of the photos in view above it.
	static func height(for screenSize: CGSize) -> CGFloat {
		min(300, max(200, screenSize.height * 0.28))
	}

	let years: [PhotoYear]

	private var state = StateManager.shared

	@Environment(\.screenSize) private var screenSize

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
			.frame(height: Self.height(for: screenSize))
			.accessibilityLabel("Map of the day’s photos")
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
