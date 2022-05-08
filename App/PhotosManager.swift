import Photos

final class PhotosFetch: Identifiable, ObservableObject {
	@Published var assets: [PHAsset]?

	let date: Date
	let yearsBack: Int
	let dateID: String

	private var task: Task<Void, Error>?

	init(fromDate date: Date, yearsBack: Int) {
		let dateID = Calendar.current.getDateID(from: date)
		self.dateID = dateID
		self.date = date
		self.yearsBack = yearsBack
		refetch()
	}

	func refetch() {
		let fetch = PHAsset.fetchAssets(yearsBack: self.yearsBack, from: self.date, dateID: self.dateID, onlyFavorites: false)
		var fetchedAssets: [PHAsset] = []
		fetch.enumerateObjects { asset, _, _ in
			fetchedAssets.append(asset)
		}
		let assets = fetchedAssets
		if assets.isEmpty {
			PhotoStateManager.shared.emptyYearsBack[self.yearsBack - 1] = true
		}
		self.assets = assets
	}
}

