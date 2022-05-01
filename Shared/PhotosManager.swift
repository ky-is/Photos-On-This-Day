import Photos

typealias ScoreAsset = (score: Float, asset: PHAsset)
typealias YearScoreAssets = (yearsBack: Int, assets: [ScoreAsset])

final class PhotosFetch: Identifiable, ObservableObject {
	@Published var assets: [PHAsset]?

	private var scoreYearPhotoList: [[ScoreAsset]] = []

	let date: Date
	let yearsBack: Int
	let dateID: String

	private var task: Task<Void, Error>?

	init(fromDate date: Date, yearsBack: Int) {
		let dateID = Self.getDateID(from: date)
		self.dateID = dateID
		self.date = date
		self.yearsBack = yearsBack
		refetch()
	}

	deinit {
		task?.cancel()
	}

	private static func getDateID(from date: Date) -> String {
		return "\(Calendar.current.component(.month, from: date))-\(Calendar.current.component(.day, from: date))"
	}

	func refetch() {
		task?.cancel()
		task = Task(priority: .userInitiated) {
			let fetch = PHAsset.fetchAssets(yearsBack: self.yearsBack, from: self.date, dateID: self.dateID, onlyFavorites: false)
			var fetchedAssets: [PHAsset] = []
			fetch.enumerateObjects { asset, _, _ in
				fetchedAssets.append(asset)
			}
			let assets = fetchedAssets
			await MainActor.run {
				if assets.isEmpty {
					PhotoStateManager.shared.emptyYearsBack[self.yearsBack - 1] = true
				}
				self.assets = assets
			}
		}
	}

	static func getBestPhotos(fromDate date: Date, yearDiffs: [Int], maxCount: Int, onlyFavorites: Bool) -> [ScoreAsset] {
		var scoreAssetsByYear: [Int: [ScoreAsset]] = [:]
		let dateID = Self.getDateID(from: date)
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
			.map { (year, scoreAssets) -> YearScoreAssets in (year, scoreAssets.sorted { $0.score > $1.score }) }
			.sorted { $0.yearsBack > $1.yearsBack }
			.map(\.assets)
		return getBestPhotos(scoreYearPhotoList: scoreYearPhotoList, maxCount: maxCount)
	}

	private static func getBestPhotos(scoreYearPhotoList: [[ScoreAsset]], maxCount: Int) -> [ScoreAsset] {
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

