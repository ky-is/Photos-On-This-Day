import Photos

typealias ScoreAsset = (score: Float, asset: PHAsset)

func getDateID(from date: Date) -> String {
	return "\(Calendar.current.component(.month, from: date))-\(Calendar.current.component(.day, from: date))"
}

func getBestPhotos(fromDate date: Date, yearDiffs: [Int], idealCount: Int, onlyFavorites: Bool) -> [ScoreAsset] {
	var scoreAssetsByYear: [Int: [ScoreAsset]] = [:]
	let dateID = getDateID(from: date)
	yearDiffs.forEach { yearsToSubtract in
		PHAsset.fetchAssets(yearsBack: yearsToSubtract, from: date, dateID: dateID, onlyFavorites: onlyFavorites).enumerateObjects { asset, index, _ in
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
