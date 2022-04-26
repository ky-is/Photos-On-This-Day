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
		if photoState.emptyYearsBack.allSatisfy({ $0 }) {
			VStack {
				Text("No photos from past years on this day")
					.font(.system(.title3, design: .rounded).weight(.medium))
				if SyncStorage.shared.filterShowShared {
					Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
						.multilineTextAlignment(.center)
						.padding()
				}
			}
				.foregroundColor(.secondary)
				.frame(maxWidth: 512)
				.padding()
		} else {
			LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
				ForEach(fetches) { fetch in
					PhotosYearView(fetch: fetch)
				}
			}
				.padding(.bottom, 32)
				.onChange(of: SyncStorage.shared.filterPhotos) { newValue in
					fetches.forEach { $0.updateFilters() }
				}
		}
	}
}

struct PhotosView_Previews: PreviewProvider {
	static var previews: some View {
		PhotosView(date: Date())
			.environment(\.screenSize, UIScreen.main.bounds.size)
	}
}
