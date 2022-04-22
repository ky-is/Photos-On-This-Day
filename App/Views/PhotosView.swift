import SwiftUI

struct PhotosView: View {
	let date: Date
	let fetches: [PhotosFetchSingleYear]

	init() {
		let date = Date()
		self.date = date
		self.fetches = (1...64).map { PhotosFetchSingleYear(fromDate: date, yearsBack: $0) }
	}

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
			ForEach(fetches) { fetch in
				PhotosYearView(fetch: fetch)
			}
		}
			.navigationTitle(DateFormatter.monthDay.string(from: date))
	}
}

struct PhotosView_Previews: PreviewProvider {
	static var previews: some View {
		PhotosView()
	}
}
