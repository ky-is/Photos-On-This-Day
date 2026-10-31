import CoreLocation
import Testing
@testable import Photos_On_This_Day

struct DayMapTests {
	private struct Item: Equatable {
		let name: String
		let latitude: Double?
		let longitude: Double?

		init(_ name: String, _ latitude: Double? = nil, _ longitude: Double? = nil) {
			self.name = name
			self.latitude = latitude
			self.longitude = longitude
		}

		var coordinate: CLLocationCoordinate2D? {
			guard let latitude, let longitude else { return nil }
			return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
		}
	}

	private func names(_ items: [Item]) -> [[String]] {
		MapPlace.group(items, coordinate: \.coordinate).map { $0.map(\.name) }
	}

	@Test func photosInTheSameSpotShareAPin() {
		let items = [Item("a", 47.60621, -122.33207), Item("b", 47.60624, -122.33211), Item("c", 47.6062, -122.3321)]
		#expect(names(items) == [["a", "b", "c"]])
	}

	@Test func photosAcrossTownGetTheirOwnPins() {
		let items = [Item("seattle", 47.6062, -122.3321), Item("tokyo", 35.6762, 139.6503), Item("seattle again", 47.6062, -122.3321)]
		#expect(names(items) == [["seattle", "seattle again"], ["tokyo"]])
	}

	@Test func photosWithoutALocationStayOffTheMap() {
		let items = [Item("none"), Item("null island", 0, 0), Item("here", 34.4208, -119.6982)]
		#expect(names(items) == [["here"]])
	}

	@Test func pinsKeepTheDaysOrder() {
		let items = [Item("newest", 40.7128, -74.006), Item("middle", 42.3601, -71.0589), Item("oldest", 37.7749, -122.4194)]
		#expect(names(items) == [["newest"], ["middle"], ["oldest"]])
	}
}
