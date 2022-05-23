import SwiftUI

struct PhotosView: View {
	let date: Date

	@ObservedObject private var syncStorage = SyncStorage.shared

	var body: some View {
		PhotosViewContent(date: date)
	}
}
struct PhotosViewContent: View {
	let fetches: [PhotosFetch]

	init(date: Date) {
		self.fetches = (1...MaxYearsBack).map { PhotosFetch(fromDate: date, yearsBack: $0) }
	}

	var body: some View {
		VStack {
			if fetches.allSatisfy({ $0.assets.isEmpty }) {
				VStack {
					Group {
						Text("No photos from past years on this day")
							.font(.system(.title3, design: .rounded).weight(.medium))
							.padding(.vertical)
						if !SyncStorage.shared.filterShowShared {
							Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
						} else {
							Text("You can browse other days\nusing the ◀︎ and ▶︎ buttons")
						}
					}
						.fixedSize(horizontal: false, vertical: true)
				}
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.frame(maxWidth: 512)
					.padding()
			} else {
				LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
					ForEach(fetches) { fetch in
						PhotosYearView(fetch: fetch)
					}
				}
			}
			if let fetch = fetches.first, let hiddenPhotosCount = SyncStorage.shared.filterPhotos[fetch.dateID]?.count, hiddenPhotosCount > 0 {
				Button {
					SyncStorage.shared.filterPhotos[fetch.dateID] = nil
				} label: {
					Text("Restore \("hidden photo".pluralize(hiddenPhotosCount))")
						.font(.system(.title3, design: .rounded))
						.padding(8)
				}
					.buttonStyle(.bordered)
					.padding(.top)
			}
		}
			.padding(.bottom, 32)
	}
}

struct PhotosView_Previews: PreviewProvider {
	static var previews: some View {
		PhotosView(date: Date.current())
			.environment(\.screenSize, UIScreen.main.bounds.size)
	}
}
