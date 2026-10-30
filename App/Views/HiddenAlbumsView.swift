import Photos
import SwiftUI

/// Turn albums off so their photos never show, in the app or its widgets: receipts, work, screenshots of things.
struct HiddenAlbumsView: View {
	@Bindable private var filters = Filters.shared
	@State private var albums: [Album] = []

	@Environment(\.dismiss) private var dismiss

	private struct Album: Identifiable {
		let id: String
		let title: String
		let photoCount: Int
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					ForEach(albums) { album in
						Toggle(isOn: Binding {
							!filters.hiddenAlbums.contains(album.id)
						} set: { isShown in
							filters.hiddenAlbums.removeAll { $0 == album.id }
							if !isShown {
								filters.hiddenAlbums.append(album.id)
							}
						}) {
							Text(album.title)
							Text("^[\(album.photoCount) photo](inflect: true)")
						}
					}
				} footer: {
					Text("Photos in albums that are turned off don't show up in On This Day or its widgets.")
				}
			}
				.navigationTitle("Hide Albums")
				.inlineNavigationTitle()
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							dismiss()
						}
					}
				}
				.task {
					albums = await Self.loadAlbums()
				}
		}
	}

	/// Your albums and shared albums, by name.
	@concurrent private static func loadAlbums() async -> [Album] {
		var albums: [Album] = []
		PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).enumerateObjects { collection, _, _ in
			let count = PHAsset.fetchAssets(in: collection, options: nil).count
			guard count > 0 else { return }
			albums.append(Album(id: collection.localIdentifier, title: collection.localizedTitle ?? "", photoCount: count))
		}
		return albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
	}
}

#Preview {
	HiddenAlbumsView()
}
