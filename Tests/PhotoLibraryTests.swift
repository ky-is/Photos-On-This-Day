import Foundation
import Photos
import Testing
@testable import Photos_On_This_Day

/// Runs against the device's real photo library, so it needs photo access.
@Suite(.enabled(if: PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized))
struct PhotoLibraryTests {
	private func allAssets() -> [PHAsset] {
		let result = PHAsset.fetchAssets(with: nil)
		return result.objects(at: IndexSet(integersIn: 0..<result.count))
	}

	@Test func hidingScreenshotsKeepsEveryOtherPhoto() {
		let all = allAssets()
		let screenshots = all.filter { $0.mediaSubtypes.contains(.photoScreenshot) }
		let filters = PhotoFilters(showScreenshots: false, showShared: true)
		let fetched = PHAsset.fetchAssets(createdBefore: .distantFuture, filters: filters)
		#expect(fetched.count == all.count - screenshots.count)
	}

	@Test func dayQueryFindsEveryPhotoOnItsDay() throws {
		let filters = PhotoFilters(showScreenshots: true, showShared: true)
		for asset in allAssets() {
			let created = try #require(asset.creationDate)
			let now = Calendar.current.date(byAdding: .year, value: 1, to: created)!
			let found = PHAsset.assetsByYearsBack(Array(0...maxYearsBack), from: now, filters: filters)[1] ?? []
			#expect(found.contains(asset), "Missing photo from \(created)")
		}
	}
}
