import Photos

typealias ScoreAsset = (score: Float, asset: PHAsset)

func getBestPhotos(fromDate date: Date, yearDiffs: [Int], idealCount: Int, onlyFavorites: Bool) -> [ScoreAsset] {
	var scoreAssetsByYear: [Int: [ScoreAsset]] = [:]
	let dateID = Calendar.current.getDateID(from: date)
	let showScreenshots = UserDefaults.shared.filterShowScreenshots
	let showShared = UserDefaults.shared.filterShowShared
	let filterPhotos = UserDefaults.shared.filterPhotos[dateID]
	yearDiffs.forEach { yearsToSubtract in
		PHAsset.fetchAssets(yearsBack: yearsToSubtract, from: date, dateID: dateID, onlyFavorites: onlyFavorites, showScreenshots: showScreenshots, showShared: showShared, filterPhotos: filterPhotos).enumerateObjects { asset, index, _ in
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
		.map { (year, scoreAssets) -> (yearsBack: Int, assets: [ScoreAsset]) in (year, scoreAssets.sorted { $0.score > $1.score }) }
		.sorted { $0.yearsBack > $1.yearsBack }
		.map(\.assets)
	return getBestPhotos(scoreYearPhotoList: scoreYearPhotoList, idealCount: idealCount)
}

func getBestPhotos(scoreYearPhotoList: [[ScoreAsset]], idealCount: Int) -> [ScoreAsset] {
	var results: [ScoreAsset] = []
	var photosByYear = scoreYearPhotoList
	while (results.count < idealCount) {
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
