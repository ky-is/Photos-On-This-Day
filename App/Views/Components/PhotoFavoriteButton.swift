import Photos
import SwiftUI

private func cacheFavorite(asset: PHAsset) {
	if asset.sourceType == .typeUserLibrary && PhotoStateManager.shared.favorites[asset] == nil {
		PhotoStateManager.shared.favorites[asset] = asset.isFavorite
	}
}

private func toggleFavorite(asset: PHAsset, isOn: Bool?) {
	PHPhotoLibrary.shared().performChanges {
		let request = PHAssetChangeRequest(for: asset)
		let willFavorite = isOn ?? PhotoStateManager.shared.favorites[asset] != true
		request.isFavorite = willFavorite
	} completionHandler: { success, error in
		DispatchQueue.main.async {
			PhotoStateManager.shared.favorites[asset]!.toggle()
		}
	}
}

struct PhotoFavoriteButton: View {
	let asset: PHAsset

	@ObservedObject private var photoState = PhotoStateManager.shared

	init(asset: PHAsset) {
		self.asset = asset
		cacheFavorite(asset: asset)
	}

	var body: some View {
		if asset.sourceType == .typeUserLibrary {
			Button {
				toggleFavorite(asset: asset, isOn: nil)
			} label: {
				Image(systemName: photoState.favorites[asset] == true ? "heart.fill" : "heart")
			}
		}
	}
}

struct PhotoFavoriteToggle: View {
	let asset: PHAsset

	@ObservedObject private var photoState = PhotoStateManager.shared

	init(asset: PHAsset) {
		self.asset = asset
		cacheFavorite(asset: asset)
	}

	var body: some View {
		if asset.sourceType == .typeUserLibrary {
			let binding = Binding(get: {
				photoState.favorites[asset] ?? false
			}, set: { isOn in
				toggleFavorite(asset: asset, isOn: isOn)
			})
			Toggle("Favorite", isOn: binding)
		}
	}
}

struct PhotoFavoriteIcon: View {
	let asset: PHAsset

	@ObservedObject private var photoState = PhotoStateManager.shared

	init(asset: PHAsset) {
		self.asset = asset
		cacheFavorite(asset: asset)
	}

	var body: some View {
		if photoState.favorites[asset] == true {
			Image(systemName: "heart.fill")
		}
	}
}

struct PhotoFavoriteButton_Previews: PreviewProvider {
	static var previews: some View {
		PhotoFavoriteButton(asset: PHAsset())
	}
}
