import SwiftUI

struct ContentView: View {
	@Bindable private var state = StateManager.shared

	@State private var showAbout = false
	/// The date picker opens from the toolbar or from Choose a Date in the menu bar.
	@Bindable private var menuActions = MenuActions.shared

	@Namespace private var photoTransition
	@State private var scrollPosition = ScrollPosition()
	@State private var scrollTracker = ScrollTracker()
	@State private var selection = GridSelection()
	/// The photo the viewer is on, so the grid can keep it in view for closing back to it.
	@State private var viewerPhotoID: String?
	@State private var pinch: GridPinch?
	@AppStorage(DayMapView.visibleKey) private var showsMap = true
	/// The scroll view's height between the bars, so a short day still fills it and can be swiped anywhere.
	@State private var visibleHeight: CGFloat = 0

	private var showsMapPanel: Bool {
		showsMap && menuActions.hasLocatedPhotos && state.canShowPhotos && !selection.isSelecting
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack {
					PermissionsView()
						.padding()
					if state.canShowPhotos {
						ShowHelpView()
						PhotosView(date: state.date, scrollPosition: $scrollPosition, scrollTracker: scrollTracker, viewerPhotoID: viewerPhotoID, pinch: pinch)
					}
				}
					.frame(maxWidth: .infinity, minHeight: visibleHeight, alignment: .top)
					.contentShape(.rect)
					.coordinateSpace(.named(GridPinch.coordinateSpace))
					// Catches a pinch anywhere on the screen, not only over photos, and hands it to the grid.
					.simultaneousGesture(MagnifyGesture()
						.onChanged { value in
							pinch = GridPinch(startLocation: value.startLocation, magnification: value.magnification)
						}
						.onEnded { _ in
							pinch?.hasEnded = true
						}, isEnabled: state.canShowPhotos)
			}
				.scrollPosition($scrollPosition)
				.scrollDisabled(selection.isDragSelecting)
				// Swipe sideways anywhere for the next or previous day, like turning a page: easier to reach than the buttons.
				.simultaneousGesture(DragGesture(minimumDistance: 30)
					.onEnded { value in
						let dx = value.translation.width
						guard abs(dx) > 80, abs(dx) > 2 * abs(value.translation.height) else { return }
						withAnimation(.smooth) {
							state.daysChange += dx < 0 ? 1 : -1
						}
					}, isEnabled: state.canShowPhotos && !selection.isSelecting)
				.onScrollGeometryChange(for: CGFloat.self) { geometry in
					geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
				} action: { _, height in
					visibleHeight = max(0, height)
				}
				.onScrollGeometryChange(for: ScrollTracker.Metrics.self) { geometry in
					ScrollTracker.Metrics(geometry)
				} action: { [scrollTracker] _, metrics in
					scrollTracker.metrics = metrics
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
					// Bigger Thumbnails in the menu is ⌘+, which takes Shift on most keyboards; ⌘= works too.
					Button("Bigger Thumbnails") {
						menuActions.columnStep = MenuActions.ColumnStep(change: -1)
					}
						.keyboardShortcut("=")
						.disabled(!state.canShowPhotos)
						.hidden()
						.accessibilityHidden(true)
				}
				.toolbar {
					ToolbarItemGroup(placement: .leadingBar) {
						if !selection.isSelecting {
							dateButtons
						}
					}
					ToolbarItemGroup(placement: .trailingBar) {
						if selection.isSelecting {
							Button("Cancel") {
								selection.end()
							}
								.keyboardShortcut(.cancelAction)
						} else if state.canShowPhotos {
							DayMapToggle()
							FilterLibraryMenu {
								showAbout = true
							}
							MoreMenu(selection: selection)
						}
					}
					ToolbarItemGroup(placement: .bottomActions) {
						if selection.isSelecting {
							SelectionActions(selection: selection)
						}
					}
				}
				.bottomBarVisibility(selection.isSelecting)
				.dayMap(date: state.date, years: menuActions.mapYears, isShown: showsMapPanel)
				.animation(.smooth, value: showsMap)
				.onChange(of: state.date) {
					selection.end()
				}
				.sheet(isPresented: $showAbout) {
					AboutView()
				}
				.sheet(isPresented: $menuActions.showsDatePicker) {
					DatePickerSheet()
				}
				.sheet(isPresented: $menuActions.showsHelp) {
					HelpView()
				}
				.navigationDestination(item: $state.openedPhoto) { selection in
					PhotoViewer(selection: selection)
						// A new link while the viewer is open starts over at that photo.
						.id(selection.id)
				}
		}
			.environment(\.photoTransition, photoTransition)
			.environment(selection)
			.environment(\.viewerShowsPhoto, { viewerPhotoID = $0 })
			.reviewPrompt()
			// Content fades softly under the bars everywhere, instead of meeting a hard edge.
			.scrollEdgeEffectStyle(.soft, for: .all)
	}

	private var dateButtons: some View {
		Group {
			Button {
				state.daysChange -= 1
			} label: {
				Image(systemName: "chevron.left")
					.font(.body.bold())
					.modifier(ToolbarButtonContentModifier())
			}
				.keyboardShortcut(.leftArrow)
				.accessibilityLabel("Previous Day")
			ToolbarButtonView("Choose a Date", imageName: state.daysChange == 0 ? "calendar" : "calendar.badge.clock") {
				menuActions.showsDatePicker = true
			}
			Button {
				state.daysChange += 1
			} label: {
				Image(systemName: "chevron.right")
					.font(.body.bold())
					.modifier(ToolbarButtonContentModifier())
			}
				.keyboardShortcut(.rightArrow)
				.accessibilityLabel("Next Day")
		}
			.disabled(!state.canShowPhotos || state.isScanning)
	}
}

extension EnvironmentValues {
	/// Tells the grid which photo the viewer is on.
	@Entry var viewerShowsPhoto: (String) -> Void = { _ in }
}

/// Share and Favorite for the selected photos, with how many there are, like in Photos.
private struct SelectionActions: View {
	let selection: GridSelection

	private var favorites = Favorites.shared

	init(selection: GridSelection) {
		self.selection = selection
	}

	private var allFavorites: Bool {
		!selection.assets.isEmpty && selection.assets.allSatisfy { favorites.isFavorite($0) }
	}

	var body: some View {
		ShareLink(items: selection.assets.map(SharedAsset.init)) { item in
			SharedAsset.preview(for: item.asset)
		}
			.disabled(selection.assets.isEmpty)
		Spacer()
		Text("^[\(selection.assets.count) photo](inflect: true)")
			.font(.subheadline.weight(.semibold))
			.fixedSize()
		Spacer()
		Button(allFavorites ? LocalizedStringKey("Unfavorite") : "Favorite", systemImage: allFavorites ? "heart.fill" : "heart") {
			// Like Photos: favorite them all, or unfavorite them all when they all already are.
			let makeFavorite = !allFavorites
			Task {
				for asset in selection.assets where favorites.isFavorite(asset) != makeFavorite {
					await favorites.toggle(asset)
				}
			}
		}
			.disabled(selection.assets.isEmpty)
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
				.inlineNavigationTitle()
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
							.keyboardShortcut(.defaultAction)
					}
				}
		}
			.presentationDetents([.medium, .large])
	}
}

/// Shows or hides the map of the day's photos pinned at the bottom of the screen.
private struct DayMapToggle: View {
	@AppStorage(DayMapView.visibleKey) private var showsMap = true

	var body: some View {
		Button {
			showsMap.toggle()
		} label: {
			Image(systemName: showsMap ? "map.fill" : "map")
				.modifier(ToolbarButtonContentModifier())
				.accessibilityLabel(showsMap ? "Hide Map" : "Show Map")
		}
			.disabled(!MenuActions.shared.hasLocatedPhotos)
	}
}

/// Library filters and grid options, with About at the end.
struct FilterLibraryMenu: View {
	let showAbout: () -> Void

	@Bindable private var filters = Filters.shared
	@AppStorage(GridSelection.aspectRatioGridKey) private var showsAspectRatio = false
	@AppStorage(PhotosView.showsThisYearKey) private var showsThisYear = false
	@AppStorage(PhotosView.oldestFirstKey) private var oldestFirst = false
	@AppStorage(Reminder.dailyKey) private var dailyReminder = false
	@State private var showsHiddenAlbums = false

	var body: some View {
		Menu {
			Toggle("Show iCloud Shared", systemImage: "shared.with.you", isOn: $filters.showShared)
			Toggle("Show Screenshots", systemImage: "camera.viewfinder", isOn: $filters.showScreenshots)
			Button("Hide Albums", systemImage: "rectangle.stack.badge.minus") {
				showsHiddenAlbums = true
			}
			Toggle("Show This Year", systemImage: "calendar.day.timeline.left", isOn: $showsThisYear)
			Toggle("Oldest First", systemImage: "arrow.up.arrow.down", isOn: $oldestFirst)
			Divider()
			// The way to resize the grid without pinching.
			Button("Bigger Thumbnails", systemImage: "plus.magnifyingglass") {
				MenuActions.shared.columnStep = MenuActions.ColumnStep(change: -1)
			}
			Button("Smaller Thumbnails", systemImage: "minus.magnifyingglass") {
				MenuActions.shared.columnStep = MenuActions.ColumnStep(change: 1)
			}
			Toggle("Aspect Ratio Grid", systemImage: "aspectratio", isOn: $showsAspectRatio)
			Divider()
			Toggle("Daily Reminder", systemImage: "bell", isOn: $dailyReminder)
			Button("About", systemImage: "questionmark.circle", action: showAbout)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonContentModifier())
				.accessibilityLabel("Filters")
		}
			.sheet(isPresented: $showsHiddenAlbums) {
				HiddenAlbumsView()
			}
			// Turning it on asks for notifications, and schedules the coming days' reminders.
			.onChange(of: dailyReminder) {
				Task {
					await Reminder.reschedule(mayAskPermission: true)
				}
			}
	}
}

/// Select, then the ways to play or share the day's photos. Always a menu, so Select never takes toolbar room of its own.
private struct MoreMenu: View {
	let selection: GridSelection

	var body: some View {
		let actions = MenuActions.shared
		Menu {
			Button("Select", systemImage: "checkmark.circle") {
				selection.start()
			}
			Divider()
			Button("Slideshow", systemImage: "play.rectangle") {
				actions.showsSlideshow = true
			}
				.disabled(!actions.hasPastPhotos)
			Button("Collage", systemImage: "square.grid.2x2") {
				actions.showsCollage = true
			}
				.disabled(!actions.hasPastPhotos)
			Divider()
			Button("Help", systemImage: "questionmark.circle") {
				actions.showsHelp = true
			}
		} label: {
			Image(systemName: "ellipsis")
				.modifier(ToolbarButtonContentModifier())
				.accessibilityLabel("More")
		}
	}
}

#Preview {
	ContentView()
}
