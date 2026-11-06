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
	/// The day whose page shows. It follows the date once that day's photos are ready, so its page slides in with them.
	@State private var pageDate = StateManager.shared.date
	/// 1 when the page coming in is a later day, sliding in from the trailing edge like turning a page; -1 for an earlier one.
	@State private var pageStep = 1
	@State private var pageChange: Task<Void, Never>?
	/// Loads the days either side of the one showing in the background, so swiping to one slides it in right away.
	@State private var neighborPreload: Task<Void, Never>?
	@State private var isSwipingDay = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

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
						// The day going out and the one coming in side by side as they slide, one page per day.
						ZStack(alignment: .top) {
							PhotosView(date: pageDate, scrollPosition: $scrollPosition, scrollTracker: scrollTracker, viewerPhotoID: viewerPhotoID, pinch: pinch)
								.id(pageDate)
								.transition(reduceMotion ? .opacity : .push(from: pageStep > 0 ? .trailing : .leading))
						}
					}
				}
					.frame(maxWidth: .infinity, minHeight: visibleHeight, alignment: .top)
					.contentShape(.rect)
					.coordinateSpace(.named(GridPinch.coordinateSpace))
					.environment(\.isSwipingDay, isSwipingDay)
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
				// Two fingers would scroll along with a pinch, fighting the grid's own scrolling to keep the pinched photo under
				// them as the columns change, so it jitters at each step.
				.scrollDisabled(selection.isDragSelecting || pinch.map { !$0.hasEnded } == true)
				// Swipe sideways anywhere for the next or previous day, like turning a page: easier to reach than the buttons.
				.simultaneousGesture(DragGesture(minimumDistance: 30)
					.onChanged { value in
						if !isSwipingDay, abs(value.translation.width) > 2 * abs(value.translation.height) {
							isSwipingDay = true
						}
					}
					.onEnded { value in
						Task {
							// The photo's tap lands as the finger lifts, just after this.
							try? await Task.sleep(for: .milliseconds(300))
							isSwipingDay = false
						}
						let dx = value.translation.width
						guard abs(dx) > 80, abs(dx) > 2 * abs(value.translation.height) else { return }
						turnDay(by: dx < 0 ? 1 : -1)
					}, isEnabled: state.canShowPhotos && !selection.isSelecting)
				// Two fingers sideways on a Mac trackpad does the same.
				.onTrackpadSwipe(isEnabled: state.canShowPhotos && !selection.isSelecting) { step in
					turnDay(by: step)
				}
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
				.onChange(of: state.date) { _, date in
					selection.end()
					// The direction first, so the page going out leaves the right way, then the new day once its photos are in.
					pageStep = date > pageDate ? 1 : -1
					pageChange?.cancel()
					neighborPreload?.cancel()
					pageChange = Task {
						// Most days are loaded already, from either side of the last one. One that isn't, such as one
						// without photos that looks for nearby days, slides in soon anyway and shows its spinner.
						let preparing = Task {
							await PhotosView.prepare(date: date)
						}
						for _ in 0..<20 where !PhotosView.isPrepared(date) {
							try? await Task.sleep(for: .milliseconds(10))
						}
						guard !Task.isCancelled else { return }
						// Each day starts at its top, with its newest year. The scroll view jumps there first, then the new page
						// joins a frame later: rows that scroll into view while a page is being added aren't drawn until the
						// next scroll, and one added far down the old day's scroll shows nothing at all.
						var transaction = Transaction(animation: nil)
						transaction.disablesAnimations = true
						withTransaction(transaction) {
							scrollPosition.scrollTo(edge: .top)
						}
						try? await Task.sleep(for: .milliseconds(20))
						// Quicker than a sheet, like turning a page.
						withAnimation(.smooth(duration: 0.3)) {
							pageDate = date
						}
						await preparing.value
						guard !Task.isCancelled else { return }
						preloadNeighbors(of: date)
					}
				}
				.onAppear {
					preloadNeighbors(of: pageDate)
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

	/// The next day (1) or the one before (-1), from a swipe.
	private func turnDay(by step: Int) {
		withAnimation(.smooth) {
			state.daysChange += step
		}
	}

	private func preloadNeighbors(of date: Date) {
		neighborPreload?.cancel()
		neighborPreload = Task(priority: .utility) {
			for step in [1, -1] {
				guard !Task.isCancelled else { return }
				await PhotosView.prepare(date: Calendar.current.date(byAdding: .day, value: step, to: date)!)
			}
		}
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
