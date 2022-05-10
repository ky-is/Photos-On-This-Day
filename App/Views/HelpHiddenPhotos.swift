import SwiftUI

struct HelpHiddenPhotos: View {
	@ObservedObject private var syncStorage = SyncStorage.shared

	var body: some View {
		let hiddenGroups = syncStorage.filterPhotos
			.filter { !$0.value.isEmpty }
			.sorted { $0.key > $1.key }
		Form {
			ForEach(hiddenGroups, id: \.key) { dateKey, photoIDs in
				Button(role: .destructive) {
					syncStorage.filterPhotos.removeValue(forKey: dateKey)
				} label: {
					HStack {
						Group {
							Text(dateKey + ":")
								.font(.system(.headline, design: .rounded))
							Text(photoIDs.count.description + " photos")
						}
							.foregroundColor(.primary)
						Spacer()
						Image(systemName: "trash")
					}
				}
			}
				.onDelete { indices in
					indices
						.map { hiddenGroups[$0].key }
						.forEach { syncStorage.filterPhotos.removeValue(forKey: $0) }
				}
		}
			.navigationTitle("Hidden Photos")
	}
}

struct HelpHiddenPhotos_Previews: PreviewProvider {
	static var previews: some View {
		HelpHiddenPhotos()
	}
}
