import SwiftUI

struct ContentView: View {
	@ObservedObject private var state = StateManager.shared

	@State private var showAbout = false

	init() {
		state.updateDate()
	}

	var body: some View {
		NavigationView {
			let canShowPhotos = state.permission == .authorized || state.permission == .limited
			ScrollView {
				PermissionsView()
					.padding()
				if canShowPhotos {
					ShowHelpView()
					PhotosView(date: state.date)
				}
			}
				.navigationTitle(DateFormatter.monthDay.string(from: state.date))
				.toolbar {
					ToolbarItemGroup(placement: .navigationBarLeading) {
						Group {
							Button {
								state.daysChange -= 1
							} label: {
								Image(systemName: "chevron.left")
									.font(.body.bold())
									.modifier(ToolbarButtonModifier())
							}
								.keyboardShortcut(.leftArrow)
							ToolbarButton("Today", imageName: "calendar.badge.clock") {
								state.daysChange = 0
							}
								.keyboardShortcut(.cancelAction)
								.disabled(state.daysChange == 0)
							Button {
								state.daysChange += 1
							} label: {
								Image(systemName: "chevron.right")
									.font(.body.bold())
									.modifier(ToolbarButtonModifier())
							}
								.keyboardShortcut(.rightArrow)
						}
							.disabled(!canShowPhotos)
					}
					ToolbarItemGroup(placement: .navigationBarTrailing) {
						if canShowPhotos {
							FilterLibraryMenu()
							ToolbarButton("About", imageName: "questionmark.circle") {
								showAbout.toggle()
							}
						}
					}
				}
				.sheet(isPresented: $showAbout) {
					AboutView()
				}
		}
			.navigationViewStyle(.stack)
	}
}

struct FilterLibraryMenu: View {
	@ObservedObject private var syncStorage = SyncStorage.shared

	var body: some View {
		Menu {
			Toggle("Show iCloud Shared", isOn: $syncStorage.filterShowShared)
			Toggle("Show Screenshots", isOn: $syncStorage.filterShowScreenshots)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonModifier())
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

