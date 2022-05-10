import Photos

final class PhotosFetch: Identifiable, ObservableObject {
	@Published var assets: [PHAsset]

	let date: Date
	let yearsBack: Int
	let dateID: String

	private var task: Task<Void, Error>?

	init(fromDate date: Date, yearsBack: Int) {
		let dateID = Calendar.current.getDateID(from: date)
		self.dateID = dateID
		self.date = date
		self.yearsBack = yearsBack
		let fetch = PHAsset.fetchAssets(yearsBack: self.yearsBack, from: self.date, dateID: self.dateID, onlyFavorites: false, showScreenshots: SyncStorage.shared.filterShowScreenshots, showShared: SyncStorage.shared.filterShowShared, filterPhotos: SyncStorage.shared.filterPhotos[dateID])
		var fetchedAssets: [PHAsset] = []
		fetch.enumerateObjects { asset, _, _ in
			fetchedAssets.append(asset)
		}
		self.assets = fetchedAssets
	}
}

