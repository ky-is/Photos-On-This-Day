import AVKit
import SwiftUI

private final class LoopingVideo {
	let player: AVQueuePlayer
	private let looper: AVPlayerLooper

	init(url: URL) {
		let item = AVPlayerItem(url: url)
		player = AVQueuePlayer(playerItem: item)
		player.isMuted = true
		player.externalPlaybackVideoGravity = .resizeAspect
		player.audiovisualBackgroundPlaybackPolicy = .pauses
		looper = AVPlayerLooper(player: player, templateItem: item)
	}
}

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.screenSize) private var screenSize

	@AppStorage(UserDefaults.Key.dismissedAddWidget) private var dismissedAddWidget = false

	@State private var video: LoopingVideo?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				ZStack {
					ProgressView("Loading video")
						.progressViewStyle(.circular)
						.labelsHidden()
					if let player = video?.player {
						VideoPlayer(player: player)
							.onAppear {
								player.play()
							}
							.onDisappear {
								player.pause()
								player.seek(to: .zero)
							}
							.onChange(of: scenePhase) { _, newPhase in
								if newPhase == .active {
									player.play()
								} else {
									player.pause()
								}
							}
					}
				}
					.ignoresSafeArea()
					.frame(maxWidth: .infinity, minHeight: (screenSize.height - 96) * 0.9)
				Text("**1.** Long press in an empty spot on your Home Screen.")
				Text("**2.** Tap the \"+\" button in the top-left.")
				Text("**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it from the list.")
				Text("**4.** Swipe left to choose a size, then press the \"Add Widget\" button at the bottom. You can configure the Widget by tapping it while edit mode is active!")
				Group {
					Text("Tip: If your photo library is sparse, the _On This Day_ Widget works best in a Smart Stack.")
					Text("Drag a system Photos Widget (with the same size) on top of this Widget to create a new Smart Stack. This lets _On This Day_ show at the top for days with photos, and otherwise the default Photos Widget will be shown as a fallback.")
				}
					.font(.callout)
				if inSheet {
					Button("Don't show again") {
						dismissedAddWidget = true
						dismiss()
					}
						.buttonStyle(.bordered)
						.frame(maxWidth: .infinity)
				}
			}
				.padding()
		}
			.onAppear {
				UIPasteboard.general.string = "On This Day"
				if video == nil {
					video = LoopingVideo(url: URL(string: "https://cdn.ky.is/photos-on-this-day/widget.mp4")!)
				}
			}
			.navigationTitle("Add a Widget")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				if inSheet {
					ToolbarItem(placement: .cancellationAction) {
						ToolbarButtonView("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
			}
	}
}

#Preview {
	HelpAddWidgetView(inSheet: true)
}
