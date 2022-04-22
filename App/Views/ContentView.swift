import SwiftUI

struct ContentView: View {
	@ObservedObject private var state = StateManager.shared

	@State private var showHelp = false

	var body: some View {
		NavigationView {
			let date = Calendar.current.date(byAdding: .init(day: state.daysChange), to: Date())!
			let canShowPhotos = state.permission == .authorized || state.permission == .limited
			ScrollView {
				PermissionsView()
					.padding()
				if canShowPhotos {
					PhotosView(date: date)
				}
			}
				.navigationTitle(DateFormatter.monthDay.string(from: date))
				.toolbar {
					ToolbarItemGroup(placement: .navigationBarLeading) {
						Group {
							Button {
								state.daysChange -= 1
							} label: {
								Image(systemName: "chevron.left")
							}
								.keyboardShortcut(.leftArrow)
							Button {
								state.daysChange = 0
							} label: {
								Image(systemName: "calendar.badge.clock")
							}
								.keyboardShortcut(.cancelAction)
								.disabled(state.daysChange == 0)
							Button {
								state.daysChange += 1
							} label: {
								Image(systemName: "chevron.right")
							}
								.keyboardShortcut(.rightArrow)
						}
							.disabled(!canShowPhotos)
					}
					ToolbarItemGroup(placement: .navigationBarTrailing) {
						if canShowPhotos {
							Button {
								showHelp.toggle()
							} label: {
								Image(systemName: "questionmark.circle")
							}
						}
					}
				}
				.sheet(isPresented: $showHelp) {
					AboutView()
				}
		}
			.navigationViewStyle(.stack)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

