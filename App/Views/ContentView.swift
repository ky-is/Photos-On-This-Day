import SwiftUI

struct ContentView: View {
	@Bindable private var state = StateManager.shared

	@State private var showAbout = false
	@State private var showDatePicker = false

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
				.background {
					// Escape jumps back to today from a hardware keyboard; the visible way is the date picker.
					Button("Today") {
						state.daysChange = 0
					}
						.keyboardShortcut(.cancelAction)
						.disabled(state.daysChange == 0)
						.hidden()
						.accessibilityHidden(true)
				}
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
							ToolbarButtonView("Choose a Date", imageName: state.daysChange == 0 ? "calendar" : "calendar.badge.clock") {
								showDatePicker = true
							}
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
				.sheet(isPresented: $showDatePicker) {
					DatePickerSheet()
				}
				.navigationDestination(item: $state.openedPhoto) { selection in
					PhotoViewer(selection: selection)
				}
		}
	}
}

private struct DatePickerSheet: View {
	private var state = StateManager.shared

	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			DatePicker("Date", selection: Binding { state.date } set: { state.go(to: $0) }, displayedComponents: .date)
				.datePickerStyle(.graphical)
				.padding()
				.navigationTitle("Choose a Date")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Today") {
							state.daysChange = 0
							dismiss()
						}
							.disabled(state.daysChange == 0)
					}
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							dismiss()
						}
					}
				}
		}
			.presentationDetents([.medium, .large])
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
