import Photos
import SwiftUI

struct PhotoFavoriteButton: View {
	let asset: PHAsset

	private var favorites = Favorites.shared

	init(asset: PHAsset) {
		self.asset = asset
	}

	var body: some View {
		if asset.sourceType == .typeUserLibrary {
			Button("Favorite", systemImage: favorites.isFavorite(asset) ? "heart.fill" : "heart") {
				Task {
					await favorites.toggle(asset)
				}
			}
		}
	}
}

struct PhotoFavoriteIcon: View {
	let asset: PHAsset

	private var favorites = Favorites.shared

	init(asset: PHAsset) {
		self.asset = asset
	}

	var body: some View {
		if asset.sourceType == .typeUserLibrary && favorites.isFavorite(asset) {
			Image(systemName: "heart.fill")
		}
	}
}

struct PhotoHideToggle: View {
	let asset: PHAsset
	let dateID: String

	private var filters = Filters.shared

	init(asset: PHAsset, dateID: String) {
		self.asset = asset
		self.dateID = dateID
	}

	var body: some View {
		Toggle("Hide from On This Day", isOn: Binding {
			filters.isHidden(asset, on: dateID)
		} set: { isOn in
			filters.setHidden(isOn, asset: asset, on: dateID)
		})
	}
}
