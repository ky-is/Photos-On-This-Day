import SwiftUI

struct PhotosView: View {
	let date: Date

	@AppStorage(UserDefaults.Key.filterPhotos) private var filterPhotos = [:]
	@AppStorage(UserDefaults.Key.filterShowShared) private var filterShowShared = false
	@AppStorage(UserDefaults.Key.filterShowScreenshots) private var filterShowScreenshots = false

	var body: some View {
		let _ = filterShowShared && filterShowScreenshots && filterPhotos.isEmpty
		PhotosViewContent(date: date)
	}
}

private struct PhotosViewContent: View {
	let hasNoPastPhotos: Bool
	let dateID: String
	let hiddenPhotosCount: Int

	let fetches: [PhotosFetch]
	let currentYearFetch: PhotosFetch?

	init(date: Date) {
		self.fetches = (1...MaxYearsBack).map { PhotosFetch(fromDate: date, yearsBack: $0) }
		self.hasNoPastPhotos = fetches.allSatisfy({ $0.assets.isEmpty })
		self.dateID = fetches.first?.dateID ?? ""
		self.hiddenPhotosCount = UserDefaults.shared.filterPhotos[dateID]?.count ?? 0
		if hasNoPastPhotos && hiddenPhotosCount == 0 && StateManager.shared.daysScanned > 0 {
			self.currentYearFetch = nil
			scanForDayWithPhotos()
		} else {
			self.currentYearFetch = self.hasNoPastPhotos ? PhotosFetch(fromDate: date, yearsBack: 0) : nil
			Task { @MainActor in
				StateManager.shared.daysScanned = 0
			}
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
							.font(.title3.weight(.medium))
							.padding(.vertical)
							.foregroundStyle(.secondary)
						if !UserDefaults.shared.filterShowShared {
							Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
								.foregroundStyle(.secondary)
						} else {
							Text("You can browse other days\nusing the ◀︎ and ▶︎ buttons")
								.foregroundStyle(.secondary)
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
				if let currentYearFetch {
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
					UserDefaults.shared.filterPhotos[dateID] = nil
				} label: {
					Text("Restore \("hidden photo".pluralize(hiddenPhotosCount))")
						.font(.title3)
						.padding(8)
				}
					.buttonStyle(.bordered)
					.padding(.top)
			}
		}
			.padding(.bottom, 32)
	}
}

#Preview {
	PhotosView(date: Date.current())
		.environment(\.screenSize, UIScreen.main.bounds.size)
}
