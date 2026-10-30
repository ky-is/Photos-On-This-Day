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
}

/// The menu bar on a Mac, and the keyboard shortcut menu on iPad.
struct AppCommands: Commands {
	@AppStorage(GridSelection.aspectRatioGridKey, store: .shared) private var showsAspectRatio = false

	private var state = StateManager.shared
	private var actions = MenuActions.shared

	var body: some Commands {
		CommandGroup(after: .newItem) {
			Button("Slideshow") {
				actions.showsSlideshow = true
			}
				.keyboardShortcut("p", modifiers: [.command, .option])
				.disabled(!state.canShowPhotos)
			Button("Collage") {
				actions.showsCollage = true
			}
				.keyboardShortcut("c", modifiers: [.command, .option])
				.disabled(!state.canShowPhotos)
		}
		CommandGroup(after: .toolbar) {
			Button("Bigger Thumbnails") {
				actions.columnStep = MenuActions.ColumnStep(change: -1)
			}
				.keyboardShortcut("+")
			Button("Smaller Thumbnails") {
				actions.columnStep = MenuActions.ColumnStep(change: 1)
			}
				.keyboardShortcut("-")
			Toggle("Aspect Ratio Grid", isOn: $showsAspectRatio)
			Divider()
		}
		CommandMenu("Go") {
			Button("Previous Day") {
				state.daysChange -= 1
			}
				.keyboardShortcut("[")
			Button("Next Day") {
				state.daysChange += 1
			}
				.keyboardShortcut("]")
			Button("Today") {
				state.daysChange = 0
			}
				.keyboardShortcut("t")
				.disabled(state.daysChange == 0)
		}
	}
}
