import SwiftUI

struct PhotosView: View {
	let date: Date
	let fetches: [PhotosFetch]

	init(date: Date) {
		self.date = date
		self.fetches = (1...MaxYearsBack).map { PhotosFetch(fromDate: date, yearsBack: $0) }
	}

	var body: some View {
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

struct PhotosView_Previews: PreviewProvider {
	static var previews: some View {
		PhotosView(date: Date())
			.environment(\.screenSize, UIScreen.main.bounds.size)
	}
}
