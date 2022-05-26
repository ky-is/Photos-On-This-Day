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
	let currentYearFetch: PhotosFetch?
	let hasNoPastPhotos: Bool
	let dateID: String
	let hiddenPhotosCount: Int

	init(date: Date) {
		self.fetches = (1...MaxYearsBack).map { PhotosFetch(fromDate: date, yearsBack: $0) }
		self.hasNoPastPhotos = fetches.allSatisfy({ $0.assets.isEmpty })
		self.dateID = fetches.first?.dateID ?? ""
		self.hiddenPhotosCount = SyncStorage.shared.filterPhotos[dateID]?.count ?? 0
		if hasNoPastPhotos && hiddenPhotosCount == 0 && StateManager.shared.daysScanned > 0 {
			self.currentYearFetch = nil
			scanForDayWithPhotos()
		} else {
			self.currentYearFetch = self.hasNoPastPhotos ? PhotosFetch(fromDate: date, yearsBack: 0) : nil
			StateManager.shared.daysScanned = 0
		}
	}

	private func scanForDayWithPhotos() {
		guard StateManager.shared.daysScanned < 365 else {
			StateManager.shared.daysScanned = 0
			return
		}
		StateManager.shared.daysScanned += 1
		StateManager.shared.daysChange -= 1
	}

	var body: some View {
		VStack {
			if hasNoPastPhotos {
				VStack {
					Group {
						Text("No photos from past years on this day")
							.font(.system(.title3, design: .rounded).weight(.medium))
							.padding(.vertical)
							.foregroundColor(.secondary)
						if !SyncStorage.shared.filterShowShared {
							Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
								.foregroundColor(.secondary)
						} else {
							Text("You can browse other days\nusing the ◀︎ and ▶︎ buttons")
								.foregroundColor(.secondary)
							Button("Find recent day with photos") {
								scanForDayWithPhotos()
							}
								.buttonStyle(.bordered)
						}
					}
						.fixedSize(horizontal: false, vertical: true)
				}
					.multilineTextAlignment(.center)
					.frame(maxWidth: 512)
					.padding()
				if let currentYearFetch = currentYearFetch {
					LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
						PhotosYearView(fetch: currentYearFetch)
					}
				}
			} else {
				LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
					ForEach(fetches) { fetch in
						PhotosYearView(fetch: fetch)
					}
				}
			}
			if hiddenPhotosCount > 0 {
				Button {
					SyncStorage.shared.filterPhotos[dateID] = nil
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
