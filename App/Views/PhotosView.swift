import SwiftUI

struct PhotosView: View {
	let date: Date
	let fetches: [PhotosFetch]

	@ObservedObject private var photoState = PhotoStateManager.shared

	init(date: Date) {
		self.date = date
		PhotoStateManager.shared.emptyYearsBack = Array(repeating: false, count: MaxYearsBack)
		self.fetches = (1...MaxYearsBack).map { PhotosFetch(fromDate: date, yearsBack: $0) }
	}

	var areAllEmpty: Bool {
		for fetch in fetches {
			guard let assets = fetch.assets else { return false }
			if !assets.isEmpty {
				return false
			}
		}
		return true
	}

	var body: some View {
		VStack {
			if photoState.emptyYearsBack.allSatisfy({ $0 }) {
				VStack {
					Text("No photos from past years on this day")
						.font(.system(.title3, design: .rounded).weight(.medium))
						.fixedSize(horizontal: false, vertical: true)
						.padding(.vertical)
					if !SyncStorage.shared.filterShowShared {
						Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
					}
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
					.onChange(of: SyncStorage.shared.filterPhotos) { newValue in
						fetches.forEach { $0.updateFilters() }
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
		PhotosView(date: Date())
			.environment(\.screenSize, UIScreen.main.bounds.size)
	}
}
