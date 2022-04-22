import Foundation
import Photos

typealias YearScoreAsset = (date: Date, score: Float, asset: PHAsset)
typealias YearScoreAssets = (yearsBack: Int, assets: [YearScoreAsset])

struct PhotosFetch {
	let scoreYearPhotoList: [[YearScoreAsset]]

	init(fromDate date: Date, yearsBack: Int) {
		var scoreAssetsByYear: [Int: [YearScoreAsset]] = [:]
		(1...yearsBack).forEach { yearsToSubtract in
			let (startDate, endDate) = Calendar.current.date(byAdding: .year, value: -yearsToSubtract, to: date)!.getStartAndEndOfDay()
			let fetchPhotosOptions = PHFetchOptions()
			fetchPhotosOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", startDate as NSDate, endDate as NSDate)
	//		fetchPhotosOptions.predicate = NSPredicate(format: "@K >= %@ AND @K < %@", #keyPath(PHAsset.creationDate), startDate as NSDate, endDate as NSDate)
	//		fetchPhotosOptions.predicate = \PHAsset.creationDate > (startDate as NSDate) && \PHAsset.creationDate < (endDate as NSDate)
			fetchPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
			fetchPhotosOptions.includeAssetSourceTypes = [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced]
			let fetch = PHAsset.fetchAssets(with: fetchPhotosOptions)
			fetch.enumerateObjects { asset, index, _ in
				let year = Calendar.current.component(.year, from: startDate)
				if scoreAssetsByYear[yearsToSubtract] == nil {
					scoreAssetsByYear[yearsToSubtract] = []
				}
				scoreAssetsByYear[yearsToSubtract]!.append((startDate, asset.isFavorite ? 1 : 0, asset))
			}
		}

		self.scoreYearPhotoList = scoreAssetsByYear
			.map { (year, scoreAssets) -> YearScoreAssets in (year, scoreAssets.sorted { $0.score > $1.score }) }
			.sorted { $0.yearsBack > $1.yearsBack }
			.map(\.assets)
	}

	func getBestPhotos(maxCount: Int) -> [YearScoreAsset] {
		var results: [YearScoreAsset] = []
		var photosByYear = scoreYearPhotoList
		while (results.count < maxCount) {
			var foundPhoto = false
			for index in photosByYear.indices {
				if !photosByYear[index].isEmpty {
					results.append(photosByYear[index].removeFirst())
					foundPhoto = true
				}
			}
			if !foundPhoto {
				break
			}
		}
		return results
	}
}

final class PhotosManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
	static let shared = PhotosManager()

	var cache: [String: PhotosFetch] = [:]

	let formatter = Date.FormatStyle().year().month(.defaultDigits).day()

	func photoLibraryDidChange(_ changeInstance: PHChange) {
		print(#function, changeInstance)
	}

	func getPhotos(from date: Date, yearsBack: Int, maxCount: Int) -> [YearScoreAsset] {
		let key = "\(date.formatted(formatter))-\(yearsBack)"
		if cache[key] == nil {
			cache[key] = PhotosFetch(fromDate: date, yearsBack: yearsBack)
		}
		return cache[key]!.getBestPhotos(maxCount: maxCount)
	}
}
