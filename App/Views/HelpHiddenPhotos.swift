import SwiftUI

struct HelpHiddenPhotos: View {
	private var filters = Filters.shared

	private struct HiddenDay: Identifiable {
		let id: String
		let date: Date?
		let count: Int
	}

	/// Hidden photo groups in calendar order. Keys are `Date.dateID` ("month-day").
	private var hiddenDays: [HiddenDay] {
		filters.hiddenPhotos
			.filter { !$0.value.isEmpty }
			.map { HiddenDay(id: $0.key, date: DayMath.date(fromDateID: $0.key), count: $0.value.count) }
			.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
	}

	var body: some View {
		let hiddenDays = hiddenDays
		Form {
			ForEach(hiddenDays) { day in
				Button(role: .destructive) {
					filters.hiddenPhotos[day.id] = nil
				} label: {
					HStack {
						Group {
							Text(day.date?.formatted(.monthDay) ?? day.id)
								.font(.headline)
							Text("^[\(day.count) photo](inflect: true)")
						}
							.foregroundStyle(.primary)
						Spacer()
						Image(systemName: "trash")
					}
				}
			}
				.onDelete { indices in
					for index in indices {
						filters.hiddenPhotos[hiddenDays[index].id] = nil
					}
				}
		}
			.navigationTitle("Hidden Photos")
	}
}

#Preview {
	HelpHiddenPhotos()
}
