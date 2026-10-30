import Photos
import SwiftUI

/// The day's photos full screen, oldest year first, each with a slow zoom and a crossfade to the next. It loops until closed.
struct SlideshowView: View {
	/// Oldest first.
	let photos: [PHAsset]

	@State private var index = 0
	@State private var image: PlatformImage?
	@State private var showsControls = false

	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.screenSize) private var screenSize
	@Environment(\.displayScale) private var displayScale

	private static let secondsPerPhoto = 4.0

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
			.overlay(alignment: .bottomLeading) {
				if let year = photos[safe: index]?.creationDate?.year {
					Text(String(year))
						.font(.system(.largeTitle, design: .rounded, weight: .bold))
						.foregroundStyle(.white)
						.shadow(color: .black.opacity(0.6), radius: 4)
						.padding(32)
						.contentTransition(.numericText())
				}
			}
			.overlay(alignment: .topLeading) {
				if showsControls {
					Button("Done") {
						dismiss()
					}
						.buttonStyle(.glass)
						.padding()
				}
			}
			.background {
				Button {
					dismiss()
				} label: {
					EmptyView()
				}
					.keyboardShortcut(.cancelAction)
					.hidden()
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
			.task {
				await play()
			}
	}

	private func play() async {
		guard !photos.isEmpty else { return }
		var next = await load(photos[0])
		var nextIndex = 0
		while !Task.isCancelled {
			let shownAt = ContinuousClock.now
			withAnimation(.easeInOut(duration: reduceMotion ? 0.3 : 1)) {
				image = next
				index = nextIndex
			}
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
