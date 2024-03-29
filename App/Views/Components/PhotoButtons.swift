import Photos
import SwiftUI

private func cacheFavorite(asset: PHAsset) {
	if asset.sourceType == .typeUserLibrary && PhotoStateManager.shared.favorites[asset] == nil {
		PhotoStateManager.shared.favorites[asset] = asset.isFavorite
	}
}

private func toggleFavorite(asset: PHAsset, isOn: Bool?) async {
	do {
		try await PHPhotoLibrary.shared().performChanges {
			let request = PHAssetChangeRequest(for: asset)
			let willFavorite = isOn ?? PhotoStateManager.shared.favorites[asset] != true
			request.isFavorite = willFavorite
		}
		await MainActor.run {
			PhotoStateManager.shared.favorites[asset]!.toggle()
		}
	} catch {
		print(#function, error.localizedDescription)
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
			ToolbarButtonView("Favorite", imageName: photoState.favorites[asset] == true ? "heart.fill" : "heart") {
				Task(priority: .userInitiated) {
					await toggleFavorite(asset: asset, isOn: nil)
				}
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
			Toggle("Favorite", isOn: Binding(get: {
				photoState.favorites[asset] ?? false
			}, set: { isOn in
				Task(priority: .userInitiated) {
					await toggleFavorite(asset: asset, isOn: isOn)
				}
			}))
		}
	}
}


struct PhotoHideToggle: View {
	let asset: PHAsset
	let dateID: String

	@ObservedObject private var syncStorage = SyncStorage.shared

	var body: some View {
		let id = asset.localIdentifier
		Toggle("Hide from On This Day", isOn: Binding(get: {
			syncStorage.filterPhotos[dateID]?.contains(id) ?? false
		}, set: { isOn in
			if syncStorage.filterPhotos[dateID] == nil {
				syncStorage.filterPhotos[dateID] = []
			}
			if isOn {
				syncStorage.filterPhotos[dateID]?.append(id)
			} else {
				syncStorage.filterPhotos[dateID] = syncStorage.filterPhotos[dateID]?.filter { $0 != id }
			}
		}))
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
