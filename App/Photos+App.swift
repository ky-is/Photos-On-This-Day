import AVFoundation
import Photos
import SwiftUI
import UniformTypeIdentifiers

// App-only Photos helpers: sharing originals, and requesting videos and Live Photos for the viewer.

/// A photo or video shared as its original file, edits included, like sharing from Photos.
nonisolated struct SharedAsset: Transferable, @unchecked Sendable {
	let asset: PHAsset

	static func preview(for asset: PHAsset) -> SharePreview<Never, Never> {
		SharePreview(asset.mediaType == .video ? "Video" : "Photo")
	}

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .movie) { try await $0.exportFile() }
			.exportingCondition { $0.asset.mediaType == .video }
		FileRepresentation(exportedContentType: .image) { try await $0.exportFile() }
			.exportingCondition { $0.asset.mediaType != .video }
	}

	private func exportFile() async throws -> SentTransferredFile {
		let resources = PHAssetResource.assetResources(for: asset)
		let types: [PHAssetResourceType] = asset.mediaType == .video ? [.fullSizeVideo, .video] : [.fullSizePhoto, .photo]
		guard let resource = types.lazy.compactMap({ type in resources.first { $0.type == type } }).first else {
			throw CocoaError(.fileNoSuchFile)
		}
		let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		let url = folder.appending(path: resource.originalFilename)
		let options = PHAssetResourceRequestOptions()
		options.isNetworkAccessAllowed = true
		try await PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options)
		return SentTransferredFile(url)
	}
}

/// Holds a value that Photos hands back on its own queue.
struct PhotosResult<Value>: @unchecked Sendable {
	let value: Value
}

extension PHImageManager {
	func playerItem(for asset: PHAsset) async -> PhotosResult<AVPlayerItem>? {
		let options = PHVideoRequestOptions()
		options.isNetworkAccessAllowed = true
		options.deliveryMode = .automatic
		return await withCheckedContinuation { continuation in
			requestPlayerItem(forVideo: asset, options: options) { item, _ in
				continuation.resume(returning: item.map(PhotosResult.init))
			}
		}
	}

	/// The final Live Photo; Photos may first deliver a lower quality one, which is skipped.
	func livePhoto(for asset: PHAsset, targetSize: CGSize) async -> PhotosResult<PHLivePhoto>? {
		let options = PHLivePhotoRequestOptions()
		options.isNetworkAccessAllowed = true
		options.deliveryMode = .highQualityFormat
		return await withCheckedContinuation { continuation in
			requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { livePhoto, _ in
				continuation.resume(returning: livePhoto.map(PhotosResult.init))
			}
		}
	}
}

extension PHPhotoLibrary {
	/// Changes the photos with these IDs. Photos runs the change on its own background queue, so it can't be main-actor code,
	/// which app code is by default: Swift stops the app when such code runs off the main thread.
	nonisolated func performChanges(onAssetsWith ids: [String], _ change: @escaping @Sendable (PHFetchResult<PHAsset>) -> Void) async throws {
		try await performChanges {
			change(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
		}
	}
}
