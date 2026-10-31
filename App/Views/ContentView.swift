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
	@AppStorage(DayMapView.visibleKey) private var showsMap = false
	/// The home indicator's strip, which the map reaches past to sit an even inset from the screen's bottom edge.
	@State private var bottomSafeArea: CGFloat = 0
	@Environment(\.screenSize) private var screenSize

	/// The map's inset from the screen's sides and bottom edge, so its bottom corners follow the display's.
	private static let mapInset: CGFloat = 8

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
				// Room under the last photos for the map, which overlaps the home indicator's strip already set aside.
				.safeAreaInset(edge: .bottom, spacing: 0) {
					Color.clear
						.frame(height: showsMapPanel ? max(0, DayMapView.height(for: screenSize) + 2 * Self.mapInset - bottomSafeArea) : 0)
				}
				// The map stays put at the bottom while the photos scroll. It's laid out from the screen's own edges, not the safe
				// area's, an even inset from the sides and bottom, so its bottom corners are concentric with the display's.
				.overlay(alignment: .bottom) {
					if showsMapPanel {
						DayMapView(years: menuActions.mapYears)
							.id(state.date)
							.clipShape(ConcentricRectangle(uniformTopCorners: .fixed(28), uniformBottomCorners: .concentric(minimum: .fixed(28))))
							.shadow(color: .black.opacity(0.2), radius: 12, y: 4)
							.padding([.horizontal, .bottom], Self.mapInset)
							.frame(maxHeight: .infinity, alignment: .bottom)
							// The full width of the screen, under the side safe areas too (iPad, iPhone on its side), so both
							// bottom corners follow the display's.
							.ignoresSafeArea(.container, edges: [.horizontal, .bottom])
							.transition(.move(edge: .bottom).combined(with: .opacity))
					}
				}
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
				.navigationDestination(item: $state.openedPhoto) { selection in
					PhotoViewer(selection: selection)
						// A new link while the viewer is open starts over at that photo.
						.id(selection.id)
				}
		}
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.safeAreaInsets.bottom
			} action: { inset in
				bottomSafeArea = inset
			}
			.environment(\.photoTransition, photoTransition)
			.environment(selection)
			.environment(\.viewerShowsPhoto, { viewerPhotoID = $0 })
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
	@AppStorage(DayMapView.visibleKey) private var showsMap = false

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
	@State private var showsHiddenAlbums = false

	var body: some View {
		Menu {
			Toggle("Show iCloud Shared", systemImage: "shared.with.you", isOn: $filters.showShared)
			Toggle("Show Screenshots", systemImage: "camera.viewfinder", isOn: $filters.showScreenshots)
			Button("Hide Albums", systemImage: "rectangle.stack.badge.minus") {
				showsHiddenAlbums = true
			}
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
			Button("About", systemImage: "questionmark.circle", action: showAbout)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonContentModifier())
				.accessibilityLabel("Filters")
		}
			.sheet(isPresented: $showsHiddenAlbums) {
				HiddenAlbumsView()
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
