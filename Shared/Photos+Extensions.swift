import Photos
import UIKit

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

extension PHImageManager {
	func requestImage(for asset: PHAsset, size: CGSize, isSynchronous: Bool, highQuality: Bool, resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
		let options = PHImageRequestOptions()
		options.isSynchronous = isSynchronous
		options.deliveryMode = highQuality ? .opportunistic : .fastFormat
		options.resizeMode = .fast
//		options.resizeMode = .exact
//		options.normalizedCropRect = CGRect(origin: .zero, size: size)
		options.isNetworkAccessAllowed = true
		let scale = size.width > 512 ? max(1, UIScreen.main.scale - 1) : UIScreen.main.scale //TODO full quality .systemExtraLarge
		let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
		requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: resultHandler)
	}
}
