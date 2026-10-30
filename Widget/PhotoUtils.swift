import Photos
import SwiftUI

nonisolated struct ScoredAsset: Sendable {
	let score: Float
	let asset: PHAsset
}

/// Picks up to `idealCount` photos, round-robin across years, preferring favorited images.
nonisolated func getBestPhotos(fromDate date: Date, yearDiffs: [Int], idealCount: Int, onlyFavorites: Bool) -> [ScoredAsset] {
	let filters = PhotoFilters.current(for: date.dateID, onlyFavorites: onlyFavorites)
	let byYearsBack = PHAsset.assetsByYearsBack(yearDiffs, from: date, filters: filters)
	let byYear = byYearsBack.keys.sorted(by: >).map { yearsBack in
		byYearsBack[yearsBack]!
			.map { asset in
				ScoredAsset(score: (asset.mediaType == .image ? 1 : 0) + (asset.isFavorite ? 1 : 0), asset: asset)
			}
			.sorted { $0.score > $1.score }
	}
	return DayMath.roundRobin(byYear, limit: idealCount)
}

/// Widget images saved to disk for the current day; older days are cleared out.
actor WidgetImageCache {
	static let shared = WidgetImageCache()

	private let containerURL = URL.cachesDirectory.appending(path: "widget", directoryHint: .isDirectory)

	func directory(for date: Date) -> URL {
		let name = date.dateID
		let url = containerURL.appending(path: name, directoryHint: .isDirectory)
		let fileManager = FileManager.default
		do {
			try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
			for child in try fileManager.contentsOfDirectory(atPath: containerURL.path()) where child != name {
				try fileManager.removeItem(at: containerURL.appending(path: child))
			}
		} catch {
			print(#function, error)
		}
		return url
	}

	/// Where the image for `asset` at `size` is stored. Widgets of different sizes crop differently, so each size gets its own file.
	nonisolated func url(for asset: PHAsset, size: CGSize, in directory: URL) -> URL {
		let id = String(asset.localIdentifier.split(separator: "/")[0])
		return directory.appending(path: "\(id)-\(Int(size.width))x\(Int(size.height)).jpg")
	}

	func cachedURL(for asset: PHAsset, size: CGSize, in directory: URL) -> URL? {
		let url = url(for: asset, size: size, in: directory)
		return FileManager.default.fileExists(atPath: url.path()) ? url : nil
	}

	func save(_ image: PlatformImage, for asset: PHAsset, size: CGSize, in directory: URL) -> URL? {
		let url = url(for: asset, size: size, in: directory)
		return autoreleasepool {
			guard let data = image.jpegData(quality: 0.8) else { return nil }
			do {
				try data.write(to: url)
				return url
			} catch {
				print(#function, error)
				return nil
			}
		}
	}
}
