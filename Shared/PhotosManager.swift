import Photos

typealias ScoreAsset = (score: Float, asset: PHAsset)
typealias YearScoreAssets = (yearsBack: Int, assets: [ScoreAsset])

final class PhotosFetchSingleYear: Identifiable, ObservableObject {
	@Published var assets: [PHAsset] = []

	private var scoreYearPhotoList: [[ScoreAsset]] = []

	let date: Date
	let yearsBack: Int

	init(fromDate date: Date, yearsBack: Int) {
		self.date = date
		self.yearsBack = yearsBack
		update()
	}

	func update() {
		Task(priority: .userInitiated) {
			let fetch = PHAsset.fetchAssets(yearsBack: yearsBack, from: date)
			var fetchedAssets: [PHAsset] = []
			fetch.enumerateObjects { asset, _, _ in
				fetchedAssets.append(asset)
			}
			let assets = fetchedAssets
			DispatchQueue.main.async {
				self.assets = assets
			}
		}
	}
}

struct PhotosFetchMultiYear {
	var bestPhotos: [ScoreAsset] = []

	init(fromDate date: Date, yearsBack: Int, maxCount: Int) {
		var scoreAssetsByYear: [Int: [ScoreAsset]] = [:]
		(1...yearsBack).forEach { yearsToSubtract in
			PHAsset.fetchAssets(yearsBack: yearsToSubtract, from: date).enumerateObjects { asset, index, _ in
				if scoreAssetsByYear[yearsToSubtract] == nil {
					scoreAssetsByYear[yearsToSubtract] = []
				}
				var score: Float = 0
				if asset.mediaType == .image {
					score += 1
				}
				if asset.isFavorite {
					score += 1
				}
				scoreAssetsByYear[yearsToSubtract]!.append((score, asset))
			}
		}
		let scoreYearPhotoList = scoreAssetsByYear
			.map { (year, scoreAssets) -> YearScoreAssets in (year, scoreAssets.sorted { $0.score > $1.score }) }
			.sorted { $0.yearsBack > $1.yearsBack }
			.map(\.assets)
		self.bestPhotos = getBestPhotos(scoreYearPhotoList: scoreYearPhotoList, maxCount: maxCount)
	}

	private func getBestPhotos(scoreYearPhotoList: [[ScoreAsset]], maxCount: Int) -> [ScoreAsset] {
		var results: [ScoreAsset] = []
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

	var cache: [String: PhotosFetchMultiYear] = [:]

	let formatter = Date.FormatStyle().year().month(.defaultDigits).day()

	func photoLibraryDidChange(_ changeInstance: PHChange) {
		print(#function, changeInstance)
	}

	private func getCache(from date: Date, yearsBack: Int, maxCount: Int) -> PhotosFetchMultiYear {
		let key = "\(date.formatted(formatter))-\(yearsBack)"
		if cache[key] == nil {
			cache[key] = PhotosFetchMultiYear(fromDate: date, yearsBack: yearsBack, maxCount: maxCount)
		}
		return cache[key]!
	}

	func getPhotos(from date: Date, yearsBack: Int, maxCount: Int) -> [ScoreAsset] {
		return getCache(from: date, yearsBack: yearsBack, maxCount: maxCount).bestPhotos
	}
}
