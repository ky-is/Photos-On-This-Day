import SwiftUI

struct HelpHiddenPhotos: View {
	var body: some View {
		let hiddenGroups = UserDefaults.shared.filterPhotos
			.filter { !$0.value.isEmpty }
			.sorted { $0.key > $1.key }
		Form {
			ForEach(hiddenGroups, id: \.key) { dateKey, photoIDs in
				Button(role: .destructive) {
					UserDefaults.shared.filterPhotos.removeValue(forKey: dateKey)
				} label: {
					HStack {
						Group {
							Text(dateKey + ":")
								.font(.headline)
							Text(photoIDs.count.description + " photos")
						}
							.foregroundStyle(.primary)
						Spacer()
						Image(systemName: "trash")
					}
				}
			}
				.onDelete { indices in
					indices
						.map { hiddenGroups[$0].key }
						.forEach { UserDefaults.shared.filterPhotos.removeValue(forKey: $0) }
				}
		}
			.navigationTitle("Hidden Photos")
	}
}

#Preview {
	HelpHiddenPhotos()
}
