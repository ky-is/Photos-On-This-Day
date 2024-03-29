import Photos
import UIKit

extension PHAsset {
	static func fetchAssets(yearsBack: Int, from date: Date, dateID: String, onlyFavorites: Bool, showScreenshots: Bool, showShared: Bool, filterPhotos: [String]?) -> PHFetchResult<PHAsset> {
		let (startDate, endDate) = Calendar.current.date(byAdding: .year, value: -yearsBack, to: date)!.getStartAndEndOfDay()
		let fetchPhotosOptions = PHFetchOptions()
		let creationPredicate: NSPredicate = \PHAsset.creationDate > startDate && \PHAsset.creationDate < endDate
		var subpredicates = [creationPredicate]
		if onlyFavorites {
			subpredicates.append(\PHAsset.isFavorite == true)
		}
		if let filterPhotos = filterPhotos, !filterPhotos.isEmpty {
			subpredicates.append(\PHAsset.localIdentifier !== filterPhotos)
		}
		if !showScreenshots {
			let sourceTypePredicate = NSPredicate(format: "NOT ((%K & %d) != 0)", #keyPath(PHAsset.mediaSubtypes), PHAssetMediaSubtype.photoScreenshot.rawValue)
			subpredicates.append(sourceTypePredicate)
		}
		fetchPhotosOptions.predicate = CompoundPredicate<PHAsset>(type: .and, subpredicates: subpredicates)
		fetchPhotosOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
		fetchPhotosOptions.includeAssetSourceTypes = showShared ? [.typeCloudShared, .typeUserLibrary, .typeiTunesSynced] : [.typeUserLibrary, .typeiTunesSynced]
		fetchPhotosOptions.includeAllBurstAssets = false
		fetchPhotosOptions.includeHiddenAssets = false
		return PHAsset.fetchAssets(with: fetchPhotosOptions)
	}
}

extension PHImageManager {
	func requestImage(for asset: PHAsset, size: CGSize, isSynchronous: Bool, cropped: Bool, resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) {
		let options = PHImageRequestOptions()
		options.isSynchronous = isSynchronous
		options.deliveryMode = .opportunistic
		options.isNetworkAccessAllowed = true
		if cropped {
			options.resizeMode = .exact
			let scaledWidth = size.width / Double(asset.pixelWidth)
			let scaledHeight = size.height / Double(asset.pixelHeight)
			let assetScaleBy = max(scaledWidth, scaledHeight)
			let assetNormalizedSize = CGSize(width: scaledWidth / assetScaleBy, height: scaledHeight / assetScaleBy)
			options.normalizedCropRect = CGRect(origin: CGPoint(x: (1 - assetNormalizedSize.width) / 2, y: (1 - assetNormalizedSize.height) / 2), size: assetNormalizedSize)
		}
		let scale = UIScreen.main.scale
		let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
		requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: resultHandler)
	}
}
