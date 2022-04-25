import Photos
import UIKit

extension PHAsset {
	static func fetchAssets(yearsBack: Int, from date: Date, onlyFavorites: Bool) -> PHFetchResult<PHAsset> {
		let includeScreenshots = UserDefaults.shared.filterShowScreenshots
		let includeShared = UserDefaults.shared.filterShowShared

		let (startDate, endDate) = Calendar.current.date(byAdding: .year, value: -yearsBack, to: date)!.getStartAndEndOfDay()
		let fetchPhotosOptions = PHFetchOptions()
		let creationPredicate: NSPredicate = \PHAsset.creationDate > startDate && \PHAsset.creationDate < endDate
		var subpredicates = [creationPredicate]
		if onlyFavorites {
			subpredicates.append(\PHAsset.isFavorite == true)
		}
		if !includeScreenshots {
			let sourceTypePredicate = NSPredicate(format: "NOT ((%K & %d) != 0)", #keyPath(PHAsset.mediaSubtypes), PHAssetMediaSubtype.photoScreenshot.rawValue)
			subpredicates.append(sourceTypePredicate)
		}
		fetchPhotosOptions.predicate = CompoundPredicate<PHAsset>(type: .and, subpredicates: subpredicates)
		fetchPhotosOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
		fetchPhotosOptions.includeAssetSourceTypes = includeShared ? [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced] : [.typeUserLibrary, .typeiTunesSynced]
		fetchPhotosOptions.includeAllBurstAssets = false
		fetchPhotosOptions.includeHiddenAssets = false
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
		let scale = size.width > 512 ? max(1, UIScreen.main.scale - 1) : (size.width > 256 ? min(2, UIScreen.main.scale) : UIScreen.main.scale) //TODO full quality
		let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
		requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: resultHandler)
	}
}
