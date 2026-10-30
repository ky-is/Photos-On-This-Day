import Photos
import SwiftUI

struct PhotoYear: Identifiable, Sendable {
	let year: Int
	let dateID: String
	let assets: [PHAsset]

	var id: Int { year }
}

private struct FetchKey: Hashable {
	let date: Date
	let filters: PhotoFilters
	let libraryRevision: Int
}

private struct LoadedPhotos {
	let date: Date
	/// Past years with photos, newest first.
	let pastYears: [PhotoYear]
	/// This year's photos, shown only when no past years have any.
	let currentYear: PhotoYear?
}

struct PhotosView: View {
	let date: Date

	private var state = StateManager.shared
	private var filters = Filters.shared

	@State private var loaded: LoadedPhotos?

	init(date: Date) {
		self.date = date
	}

	private var dateID: String { date.dateID }

	private var hiddenPhotosCount: Int {
		filters.hiddenPhotos[dateID]?.count ?? 0
	}

	var body: some View {
		VStack {
			if let loaded, loaded.date == date {
				if loaded.pastYears.isEmpty {
					noPastPhotos
					if let currentYear = loaded.currentYear {
						LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
							PhotosYearView(year: currentYear)
						}
					}
				} else {
					LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
						ForEach(loaded.pastYears) { year in
							PhotosYearView(year: year)
						}
					}
				}
				if hiddenPhotosCount > 0 {
					Button {
						filters.hiddenPhotos[dateID] = nil
					} label: {
						Text("Restore ^[\(hiddenPhotosCount) hidden photo](inflect: true)")
							.font(.title3)
							.padding(8)
					}
						.buttonStyle(.bordered)
						.padding(.top)
				}
			} else {
				ProgressView()
					.padding()
			}
		}
			.padding(.bottom, 32)
			.task(id: FetchKey(date: date, filters: filters.photoFilters(for: dateID), libraryRevision: state.libraryRevision)) {
				let photos = await Self.load(date: date, filters: filters.photoFilters(for: dateID))
				if !Task.isCancelled {
					loaded = photos
				}
			}
	}

	private var noPastPhotos: some View {
		VStack {
			Group {
				Text("No photos from past years on this day")
					.font(.title3.weight(.medium))
					.padding(.vertical)
					.foregroundStyle(.secondary)
				if !filters.showShared {
					Text("Try enabling iCloud Shared photos from the filter button at the top to include photos from friends and family!")
						.foregroundStyle(.secondary)
				} else {
					Text("You can browse other days\nusing the ◀︎ and ▶︎ buttons")
						.foregroundStyle(.secondary)
					Button {
						Task {
							await state.scanForDayWithPhotos()
						}
					} label: {
						if state.isScanning {
							ProgressView()
						} else {
							Text("Find recent day with photos")
						}
					}
						.buttonStyle(.bordered)
						.disabled(state.isScanning)
				}
			}
				.fixedSize(horizontal: false, vertical: true)
		}
			.multilineTextAlignment(.center)
			.frame(maxWidth: 512)
			.padding()
	}

	@concurrent private static func load(date: Date, filters: PhotoFilters) async -> LoadedPhotos {
		let dateID = date.dateID
		let byYearsBack = PHAsset.assetsByYearsBack(Array(0...maxYearsBack), from: date, filters: filters)
		let pastYears = byYearsBack
			.filter { $0.key > 0 }
			.sorted { $0.key < $1.key }
			.map { PhotoYear(year: date.year - $0.key, dateID: dateID, assets: $0.value) }
		let currentYear = pastYears.isEmpty ? byYearsBack[0].map { PhotoYear(year: date.year, dateID: dateID, assets: $0) } : nil
		return LoadedPhotos(date: date, pastYears: pastYears, currentYear: currentYear)
	}
}

#Preview {
	PhotosView(date: Date.current())
		.environment(\.screenSize, CGSize(width: 390, height: 844))
}
