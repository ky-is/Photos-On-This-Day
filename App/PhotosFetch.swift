import Photos

@Observable final class PhotosFetch: Identifiable {
	var assets: [PHAsset]

	let yearsBack: Int
	let dateID: String

	private var task: Task<Void, Error>?

	init(fromDate date: Date, yearsBack: Int) {
		let dateID = Calendar.current.getDateID(from: date)
		self.dateID = dateID
		self.yearsBack = yearsBack
		let fetch = PHAsset.fetchAssets(yearsBack: yearsBack, from: date, dateID: dateID, onlyFavorites: false, showScreenshots: UserDefaults.shared.filterShowScreenshots, showShared: UserDefaults.shared.filterShowShared, filterPhotos: UserDefaults.shared.filterPhotos[dateID])
		var fetchedAssets: [PHAsset] = []
		fetch.enumerateObjects { asset, _, _ in
			fetchedAssets.append(asset)
		}
		self.assets = fetchedAssets
	}
}
