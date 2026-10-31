import Photos
import SwiftUI

/// The day's photos full screen, oldest year first, each with a slow zoom and a crossfade to the next. It loops until closed.
struct SlideshowView: View {
	/// Oldest first.
	let photos: [PHAsset]

	@State private var index = 0
	@State private var image: PlatformImage?
	@State private var showsControls = false
	/// Changing this restarts the show from its photo.
	@State private var playback = Playback()

	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	private static let secondsPerPhoto = 4.0

	private struct Playback: Equatable {
		var start = 0
		var isPaused = false
	}

	var body: some View {
		ZStack {
			Color.black
			if let image {
				Image(platformImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.modifier(SlowZoom(isOn: !reduceMotion, duration: Self.secondsPerPhoto + 1))
					// A new view for each photo, so it fades in over the last one.
					.id(index)
					.transition(.opacity)
			}
		}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(photos[safe: index].map { PhotosYearThumbnail.accessibilityDescription(of: $0, isFavorite: Favorites.shared.isFavorite($0)) } ?? Text(verbatim: ""))
			.accessibilityAddTraits(.isImage)
			.accessibilityActions {
				if playback.isPaused {
					Button("Play", action: togglePause)
				} else {
					Button("Pause", action: togglePause)
				}
				Button("Next Photo") {
					step(by: 1)
				}
				Button("Previous Photo") {
					step(by: -1)
				}
			}
			.overlay(alignment: .bottomLeading) {
				if let year = photos[safe: index]?.creationDate?.year {
					Text(String(year))
						.font(.system(.largeTitle, design: .rounded, weight: .bold))
						.foregroundStyle(.white)
						.shadow(color: .black.opacity(0.6), radius: 4)
						.padding(32)
						.contentTransition(.numericText())
						// The photo's label already says when.
						.accessibilityHidden(true)
				}
			}
			.overlay(alignment: .topLeading) {
				// Always there with VoiceOver, which can't tap to show them.
				if showsControls || voiceOverEnabled {
					HStack {
						Button("Done") {
							dismiss()
						}
						Button(action: togglePause) {
							if playback.isPaused {
								Label("Play", systemImage: "play.fill")
							} else {
								Label("Pause", systemImage: "pause.fill")
							}
						}
							.labelStyle(.iconOnly)
					}
						.buttonStyle(.glass)
						.padding()
				}
			}
			.background {
				// Escape closes, Space pauses or plays, and the arrow keys step through the photos.
				Group {
					Button {
						dismiss()
					} label: {
						EmptyView()
					}
						.keyboardShortcut(.cancelAction)
					Button(action: togglePause) {
						EmptyView()
					}
						.keyboardShortcut(.space, modifiers: [])
					Button {
						step(by: -1)
					} label: {
						EmptyView()
					}
						.keyboardShortcut(.leftArrow, modifiers: [])
					Button {
						step(by: 1)
					} label: {
						EmptyView()
					}
						.keyboardShortcut(.rightArrow, modifiers: [])
				}
					.hidden()
					.accessibilityHidden(true)
			}
			.accessibilityAction(.escape) {
				dismiss()
			}
			.ignoresSafeArea()
			.hidesSystemOverlays()
			.contentShape(.rect)
			.onTapGesture {
				withAnimation {
					showsControls.toggle()
				}
			}
			.keepsScreenAwake()
			.task(id: playback) {
				await play(playback)
			}
	}

	private func togglePause() {
		playback = Playback(start: index, isPaused: !playback.isPaused)
	}

	/// Shows the next or previous photo, staying paused if paused.
	private func step(by change: Int) {
		guard !photos.isEmpty else { return }
		playback = Playback(start: (index + change + photos.count) % photos.count, isPaused: playback.isPaused)
	}

	/// Shows the photo it starts at, then moves on every few seconds unless paused.
	private func play(_ playback: Playback) async {
		guard photos.indices.contains(playback.start) else { return }
		var nextIndex = playback.start
		var next: PlatformImage?
		if nextIndex == index, image != nil {
			next = image
		} else {
			next = await load(photos[nextIndex])
		}
		while !Task.isCancelled {
			let shownAt = ContinuousClock.now
			withAnimation(.easeInOut(duration: reduceMotion ? 0.3 : 1)) {
				image = next
				index = nextIndex
			}
			if playback.isPaused { return }
			nextIndex = (nextIndex + 1) % photos.count
			// Load the next photo while this one shows.
			next = await load(photos[nextIndex])
			try? await Task.sleep(until: shownAt + .seconds(Self.secondsPerPhoto))
		}
	}

	private func load(_ asset: PHAsset) async -> PlatformImage? {
		await PHImageManager.default().image(for: asset, size: screenSize, scale: displayScale, cropped: false)
	}
}

/// Slowly zooms in from the moment the photo appears.
private struct SlowZoom: ViewModifier {
	let isOn: Bool
	let duration: Double

	@State private var scale = 1.0

	func body(content: Content) -> some View {
		content
			.scaleEffect(scale)
			.onAppear {
				guard isOn else { return }
				withAnimation(.linear(duration: duration)) {
					scale = 1.08
				}
			}
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
