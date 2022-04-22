import Foundation
import Photos

typealias DateScoreAsset = (date: Date, score: Float, asset: PHAsset)
typealias YearScoreAssets = (yearsBack: Int, assets: [DateScoreAsset])

struct PhotosFetch {
	let scoreYearPhotoList: [[DateScoreAsset]]

	init(fromDate date: Date, yearsBack: Int) {
		var scoreAssetsByYear: [Int: [DateScoreAsset]] = [:]
		(1...yearsBack).forEach { yearsToSubtract in
			let (startDate, endDate) = Calendar.current.date(byAdding: .year, value: -yearsToSubtract, to: date)!.getStartAndEndOfDay()
			let fetchPhotosOptions = PHFetchOptions()
			fetchPhotosOptions.predicate = \PHAsset.creationDate > startDate && \PHAsset.creationDate < endDate
			fetchPhotosOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
			fetchPhotosOptions.includeAssetSourceTypes = [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced]
			let fetch = PHAsset.fetchAssets(with: fetchPhotosOptions)
			fetch.enumerateObjects { asset, index, _ in
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

	func getBestPhotos(maxCount: Int) -> [DateScoreAsset] {
		var results: [DateScoreAsset] = []
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

	func getPhotos(from date: Date, yearsBack: Int, maxCount: Int) -> [DateScoreAsset] {
		let key = "\(date.formatted(formatter))-\(yearsBack)"
		if cache[key] == nil {
			cache[key] = PhotosFetch(fromDate: date, yearsBack: yearsBack)
		}
		return cache[key]!.getBestPhotos(maxCount: maxCount)
	}
}
