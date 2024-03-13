import SwiftUI

struct ContentView: View {
	var state = StateManager.shared

	@State private var showAbout = false

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
									.modifier(ToolbarButtonContentModifier())
							}
								.keyboardShortcut(.leftArrow)
							ToolbarButtonView("Today", imageName: "calendar.badge.clock") {
								state.daysChange = 0
							}
								.keyboardShortcut(.cancelAction)
								.disabled(state.daysChange == 0)
							Button {
								state.daysChange += 1
							} label: {
								Image(systemName: "chevron.right")
									.font(.body.bold())
									.modifier(ToolbarButtonContentModifier())
							}
								.keyboardShortcut(.rightArrow)
						}
							.disabled(!canShowPhotos)
					}
					ToolbarItemGroup(placement: .navigationBarTrailing) {
						if canShowPhotos {
							FilterLibraryMenu()
							ToolbarButtonView("About", imageName: "questionmark.circle") {
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
	@AppStorage(UserDefaults.Key.filterShowShared) private var filterShowShared = false
	@AppStorage(UserDefaults.Key.filterShowScreenshots) private var filterShowScreenshots = false

	var body: some View {
		Menu {
			Toggle("Show iCloud Shared", isOn: $filterShowShared)
			Toggle("Show Screenshots", isOn: $filterShowScreenshots)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonContentModifier())
		}
	}
}

#Preview {
	ContentView()
}

