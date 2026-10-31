import SwiftUI

struct ContentView: View {
	@Bindable private var state = StateManager.shared

	@State private var showAbout = false
	@State private var showDatePicker = false

	@Namespace private var photoTransition
	@State private var scrollPosition = ScrollPosition()
	@State private var scrollTracker = ScrollTracker()
	@State private var selection = GridSelection()
	/// The photo the viewer is on, so the grid can keep it in view for closing back to it.
	@State private var viewerPhotoID: String?
	@State private var pinch: GridPinch?

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
				.onChange(of: state.date) {
					selection.end()
				}
				.sheet(isPresented: $showAbout) {
					AboutView()
				}
				.sheet(isPresented: $showDatePicker) {
					DatePickerSheet()
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
		Button("Favorite", systemImage: allFavorites ? "heart.fill" : "heart") {
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
					}
				}
		}
			.presentationDetents([.medium, .large])
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
			Toggle("Aspect Ratio Grid", systemImage: "aspectratio", isOn: $showsAspectRatio)
			Divider()
			Button("About", systemImage: "questionmark.circle", action: showAbout)
		} label: {
			Image(systemName: "line.3.horizontal.decrease.circle")
				.modifier(ToolbarButtonContentModifier())
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
