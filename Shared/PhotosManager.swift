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
			let fetch = PHAsset.fetchAssets(yearsBack: yearsBack, from: date, onlyFavorites: false)
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

func getBestPhotos(fromDate date: Date, yearDiffs: [Int], maxCount: Int, onlyFavorites: Bool) -> [ScoreAsset] {
	var scoreAssetsByYear: [Int: [ScoreAsset]] = [:]
	yearDiffs.forEach { yearsToSubtract in
		PHAsset.fetchAssets(yearsBack: yearsToSubtract, from: date, onlyFavorites: onlyFavorites).enumerateObjects { asset, index, _ in
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
	return getBestPhotos(scoreYearPhotoList: scoreYearPhotoList, maxCount: maxCount)
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
