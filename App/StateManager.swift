import Photos
import SwiftUI
import WidgetKit
import os

let logger = Logger(subsystem: "is.ky.Photos-On-This-Day", category: "App")

@Observable final class StateManager {
	static let shared = StateManager()

	private(set) var today = Date.current()
	var daysChange = 0
	private(set) var isScanning = false
	/// Bumped whenever the photo library changes, so loaded photos refresh.
	private(set) var libraryRevision = 0

	private var libraryObserver: LibraryObserver?

	var date: Date {
		Calendar.current.date(byAdding: .day, value: daysChange, to: today)!
	}

	var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if canShowPhotos {
				WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
			}
		}
	}

	var canShowPhotos: Bool {
		permission == .authorized || permission == .limited
	}

	func requestPermission() async {
		if !canShowPhotos {
			permission = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
		}
		observeLibrary()
	}

	/// Picks up a new day and permission changes made in Settings when the app becomes active.
	func refresh() {
		let now = Date.current()
		if !Calendar.current.isDate(now, inSameDayAs: today) {
			today = now
			daysChange = 0
		}
		let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
		if status != permission {
			permission = status
			observeLibrary()
		}
	}

	private func observeLibrary() {
		guard canShowPhotos, libraryObserver == nil else { return }
		let observer = LibraryObserver {
			Task { @MainActor in
				StateManager.shared.libraryRevision += 1
			}
		}
		PHPhotoLibrary.shared().register(observer)
		libraryObserver = observer
	}

	/// Steps back to the nearest earlier day that has photos from past years.
	func scanForDayWithPhotos() async {
		isScanning = true
		defer { isScanning = false }
		let filters = Filters.shared
		if let daysBack = await Self.nearestDayWithPhotos(before: date, showScreenshots: filters.showScreenshots, showShared: filters.showShared, hiddenPhotos: filters.hiddenPhotos) {
			daysChange -= daysBack
		}
	}

	@concurrent private static func nearestDayWithPhotos(before date: Date, showScreenshots: Bool, showShared: Bool, hiddenPhotos: [String: [String]]) async -> Int? {
		// Every photo from a past year of the scanned days (up to a year back) was taken before this cutoff.
		let calendar = Calendar.current
		let cutoff = calendar.startOfDay(for: calendar.date(byAdding: .year, value: -1, to: date)!)
		let filters = PhotoFilters(showScreenshots: showScreenshots, showShared: showShared)
		var dayIDsWithPhotos = Set<String>()
		PHAsset.fetchAssets(createdBefore: cutoff, filters: filters).enumerateObjects { asset, _, stop in
			guard let dayID = asset.creationDate?.dateID, !dayIDsWithPhotos.contains(dayID) else { return }
			if hiddenPhotos[dayID]?.contains(asset.localIdentifier) != true {
				dayIDsWithPhotos.insert(dayID)
				if dayIDsWithPhotos.count >= 366 || Task.isCancelled {
					stop.pointee = true
				}
			}
		}
		return (1...365).first { daysBack in
			dayIDsWithPhotos.contains(calendar.date(byAdding: .day, value: -daysBack, to: date)!.dateID)
		}
	}
}

/// Photos calls this on a background queue.
private final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
	private let onChange: @Sendable () -> Void

	init(onChange: @escaping @Sendable () -> Void) {
		self.onChange = onChange
	}

	nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
		onChange()
	}
}

/// Library filters shared with the widget, which reloads whenever they change.
@Observable final class Filters {
	static let shared = Filters()

	var showShared = UserDefaults.shared.filterShowShared {
		didSet { UserDefaults.shared.filterShowShared = showShared; reloadWidget() }
	}
	var showScreenshots = UserDefaults.shared.filterShowScreenshots {
		didSet { UserDefaults.shared.filterShowScreenshots = showScreenshots; reloadWidget() }
	}
	/// Hidden photo IDs, keyed by `Date.dateID`.
	var hiddenPhotos = UserDefaults.shared.filterPhotos {
		didSet { UserDefaults.shared.filterPhotos = hiddenPhotos; reloadWidget() }
	}

	func photoFilters(for dateID: String) -> PhotoFilters {
		PhotoFilters(showScreenshots: showScreenshots, showShared: showShared, hiddenIDs: hiddenPhotos[dateID] ?? [])
	}

	func isHidden(_ asset: PHAsset, on dateID: String) -> Bool {
		hiddenPhotos[dateID]?.contains(asset.localIdentifier) ?? false
	}

	func setHidden(_ isHidden: Bool, asset: PHAsset, on dateID: String) {
		var ids = hiddenPhotos[dateID] ?? []
		ids.removeAll { $0 == asset.localIdentifier }
		if isHidden {
			ids.append(asset.localIdentifier)
		}
		hiddenPhotos[dateID] = ids.isEmpty ? nil : ids
	}

	private func reloadWidget() {
		WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
	}
}

/// Favorite state, cached so toggles show immediately.
@Observable final class Favorites {
	static let shared = Favorites()

	private var cache: [String: Bool] = [:]

	func isFavorite(_ asset: PHAsset) -> Bool {
		cache[asset.localIdentifier] ?? asset.isFavorite
	}

	func toggle(_ asset: PHAsset) async {
		let willFavorite = !isFavorite(asset)
		do {
			try await PHPhotoLibrary.shared().performChanges {
				PHAssetChangeRequest(for: asset).isFavorite = willFavorite
			}
			cache[asset.localIdentifier] = willFavorite
		} catch {
			logger.error("Favorite failed: \(error.localizedDescription)")
		}
	}
}

extension EnvironmentValues {
	@Entry var screenSize: CGSize = .zero
}
