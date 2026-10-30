import Photos
import UIKit

nonisolated struct PhotoFilters: Hashable, Sendable {
	var showScreenshots: Bool
	var showShared: Bool
	var onlyFavorites = false
	var hiddenIDs: [String] = []

	static func current(for dateID: String, onlyFavorites: Bool = false) -> Self {
		let defaults = UserDefaults.shared
		return PhotoFilters(showScreenshots: defaults.filterShowScreenshots, showShared: defaults.filterShowShared, onlyFavorites: onlyFavorites, hiddenIDs: defaults.filterPhotos[dateID] ?? [])
	}
}

nonisolated extension PHAsset {
	static func fetchAssets(createdBefore end: Date, filters: PhotoFilters) -> PHFetchResult<PHAsset> {
		fetchAssets(with: fetchOptions(filters: filters, extra: [NSPredicate(format: "creationDate < %@", end as NSDate)]))
	}

	/// Photos from the same day in each of the given past years, in one query, keyed by years back.
	static func assetsByYearsBack(_ yearsBack: [Int], from date: Date, filters: PhotoFilters) -> [Int: [PHAsset]] {
		guard !yearsBack.isEmpty else { return [:] }
		let calendar = Calendar.current
		let dayRanges = yearsBack.map { yearsBack in
			let (start, end) = calendar.date(byAdding: .year, value: -yearsBack, to: date)!.startAndEndOfDay
			return NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
		}
		let options = fetchOptions(filters: filters, extra: [NSCompoundPredicate(orPredicateWithSubpredicates: dayRanges)])
		let currentYear = date.year
		var byYearsBack: [Int: [PHAsset]] = [:]
		fetchAssets(with: options).enumerateObjects { asset, _, _ in
			guard let created = asset.creationDate else { return }
			byYearsBack[currentYear - created.year, default: []].append(asset)
		}
		return byYearsBack
	}

	private static func fetchOptions(filters: PhotoFilters, extra predicates: [NSPredicate]) -> PHFetchOptions {
		var predicates = predicates
		if filters.onlyFavorites {
			predicates.append(NSPredicate(format: "isFavorite == YES"))
		}
		if !filters.hiddenIDs.isEmpty {
			predicates.append(NSPredicate(format: "NOT (localIdentifier IN %@)", filters.hiddenIDs))
		}
		if !filters.showScreenshots {
			// Photos mistranslates "(mediaSubtypes & x) == 0" and drops every asset without subtypes, so keep this form.
			predicates.append(NSPredicate(format: "NOT ((mediaSubtypes & %d) != 0)", PHAssetMediaSubtype.photoScreenshot.rawValue))
		}
		let options = PHFetchOptions()
		options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
		options.includeAssetSourceTypes = filters.showShared ? [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced] : [.typeUserLibrary, .typeiTunesSynced]
		options.includeAllBurstAssets = false
		options.includeHiddenAssets = false
		return options
	}
}

nonisolated extension PHImageManager {
	private static func options(for asset: PHAsset, size: CGSize, cropped: Bool, deliveryMode: PHImageRequestOptionsDeliveryMode) -> PHImageRequestOptions {
		let options = PHImageRequestOptions()
		options.deliveryMode = deliveryMode
		options.isNetworkAccessAllowed = true
		if cropped {
			options.resizeMode = .exact
			let scaledWidth = size.width / Double(asset.pixelWidth)
			let scaledHeight = size.height / Double(asset.pixelHeight)
			let scaleBy = max(scaledWidth, scaledHeight)
			let normalizedSize = CGSize(width: scaledWidth / scaleBy, height: scaledHeight / scaleBy)
			options.normalizedCropRect = CGRect(origin: CGPoint(x: (1 - normalizedSize.width) / 2, y: (1 - normalizedSize.height) / 2), size: normalizedSize)
		}
		return options
	}

	/// Streams a fast degraded image first, then the full quality one.
	func images(for asset: PHAsset, size: CGSize, scale: CGFloat, cropped: Bool) -> AsyncStream<(image: UIImage, isDegraded: Bool)> {
		AsyncStream { continuation in
			let options = Self.options(for: asset, size: size, cropped: cropped, deliveryMode: .opportunistic)
			let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
			let requestID = requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
				let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
				if let image {
					continuation.yield((image, isDegraded))
				}
				if !isDegraded {
					continuation.finish()
				}
			}
			continuation.onTermination = { [weak self] _ in
				self?.cancelImageRequest(requestID)
			}
		}
	}

	/// The full quality image only.
	func image(for asset: PHAsset, size: CGSize, scale: CGFloat, cropped: Bool) async -> UIImage? {
		let options = Self.options(for: asset, size: size, cropped: cropped, deliveryMode: .highQualityFormat)
		let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
		return await withCheckedContinuation { continuation in
			requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
				continuation.resume(returning: image)
			}
		}
	}
}
