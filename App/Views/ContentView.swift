import SwiftUI

struct ContentView: View {
	private var state = StateManager.shared

	@State private var showAbout = false

	var body: some View {
		NavigationStack {
			ScrollView {
				PermissionsView()
					.padding()
				if state.canShowPhotos {
					ShowHelpView()
					PhotosView(date: state.date)
				}
			}
				.navigationTitle(state.date.formatted(.monthDay))
				.toolbar {
					ToolbarItemGroup(placement: .topBarLeading) {
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
							.disabled(!state.canShowPhotos || state.isScanning)
					}
					ToolbarItemGroup(placement: .topBarTrailing) {
						if state.canShowPhotos {
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
	}
}

struct FilterLibraryMenu: View {
	@Bindable private var filters = Filters.shared

	var body: some View {
		Menu {
			Toggle("Show iCloud Shared", isOn: $filters.showShared)
			Toggle("Show Screenshots", isOn: $filters.showScreenshots)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonContentModifier())
		}
	}
}

#Preview {
	ContentView()
}
