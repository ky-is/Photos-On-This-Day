import Photos

extension PHAsset {
	static func fetchAssets(yearsBack: Int, from date: Date, areDuplicatesAcceptable: Bool) -> PHFetchResult<PHAsset> {
		let (startDate, endDate) = Calendar.current.date(byAdding: .year, value: -yearsBack, to: date)!.getStartAndEndOfDay()
		let fetchPhotosOptions = PHFetchOptions()
		let creationPredicate: NSPredicate = \PHAsset.creationDate > startDate && \PHAsset.creationDate < endDate
		let sourceTypePredicate = NSPredicate(format: "NOT ((%K & %d) != 0)", #keyPath(PHAsset.mediaSubtypes), PHAssetMediaSubtype.photoScreenshot.rawValue)
		fetchPhotosOptions.predicate = CompoundPredicate<PHAsset>(type: .and, subpredicates: [creationPredicate, sourceTypePredicate])
		fetchPhotosOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
		fetchPhotosOptions.includeAssetSourceTypes = areDuplicatesAcceptable ? [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced] : [.typeUserLibrary, .typeiTunesSynced]
		fetchPhotosOptions.includeAllBurstAssets = false
		return PHAsset.fetchAssets(with: fetchPhotosOptions)
	}
}
