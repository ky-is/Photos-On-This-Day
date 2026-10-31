import SwiftUI

/// Requests from the menu bar that the grid carries out. Menus can't reach into a view's state, so they set these.
@Observable final class MenuActions {
	static let shared = MenuActions()

	/// One column fewer (bigger thumbnails) or more, each time it's set.
	struct ColumnStep: Equatable {
		let change: Int
		let id = UUID()
	}

	var columnStep: ColumnStep?
	var showsSlideshow = false
	var showsCollage = false
	var showsDatePicker = false
	/// Whether the day has photos from past years, so Slideshow and Collage have something to show.
	var hasPastPhotos = false
	/// The day's years when any of their photos has a location, for the map pinned at the bottom of the main screen.
	var mapYears: [PhotoYear] = []
	var hasLocatedPhotos: Bool { !mapYears.isEmpty }
}

/// The menu bar on a Mac, and the keyboard shortcut menu on iPad.
struct AppCommands: Commands {
	// Menu commands are outside the views, which get the shared store from the app's .defaultAppStorage.
	@AppStorage(GridSelection.aspectRatioGridKey, store: .shared) private var showsAspectRatio = false
	@AppStorage(DayMapView.visibleKey, store: .shared) private var showsMap = false

	private var state = StateManager.shared
	private var actions = MenuActions.shared

	var body: some Commands {
		CommandGroup(after: .newItem) {
			Button("Slideshow", systemImage: "play.rectangle") {
				actions.showsSlideshow = true
			}
				.keyboardShortcut("p", modifiers: [.command, .option])
				.disabled(!state.canShowPhotos || !actions.hasPastPhotos)
			Button("Collage", systemImage: "square.grid.2x2") {
				actions.showsCollage = true
			}
				.keyboardShortcut("c", modifiers: [.command, .option])
				.disabled(!state.canShowPhotos || !actions.hasPastPhotos)
		}
		CommandGroup(after: .toolbar) {
			Button("Bigger Thumbnails", systemImage: "plus.magnifyingglass") {
				actions.columnStep = MenuActions.ColumnStep(change: -1)
			}
				.keyboardShortcut("+")
			Button("Smaller Thumbnails", systemImage: "minus.magnifyingglass") {
				actions.columnStep = MenuActions.ColumnStep(change: 1)
			}
				.keyboardShortcut("-")
			Toggle("Aspect Ratio Grid", systemImage: "aspectratio", isOn: $showsAspectRatio)
			Toggle("Show Map", systemImage: "map", isOn: $showsMap)
				.keyboardShortcut("m", modifiers: [.command, .option])
				.disabled(!state.canShowPhotos || !actions.hasLocatedPhotos)
			Divider()
		}
		CommandMenu("Go") {
			Button("Previous Day", systemImage: "chevron.left") {
				state.daysChange -= 1
			}
				.keyboardShortcut("[")
			Button("Next Day", systemImage: "chevron.right") {
				state.daysChange += 1
			}
				.keyboardShortcut("]")
			Button("Today", systemImage: "calendar") {
				state.daysChange = 0
			}
				.keyboardShortcut("t")
				.disabled(state.daysChange == 0)
			Button("Choose a Date…", systemImage: "calendar") {
				actions.showsDatePicker = true
			}
				.keyboardShortcut("d")
				.disabled(!state.canShowPhotos || state.isScanning)
		}
	}
}
