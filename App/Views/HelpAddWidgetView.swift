import AVKit
import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss
	@Environment(\.scenePhase) private var scenePhase

	@ObservedObject private var environment = EnvironmentManager.shared

	@State private var loading = false

	private let player: AVQueuePlayer
	private let looper: AVPlayerLooper

	init(inSheet: Bool) {
		self.inSheet = inSheet
		let item = AVPlayerItem(url: URL(string: "https://kcdn.netlify.app/widget.mov")!)
		player = AVQueuePlayer(playerItem: item)
		player.isMuted = true
		player.externalPlaybackVideoGravity = .resizeAspect
		player.audiovisualBackgroundPlaybackPolicy = .pauses
		looper = AVPlayerLooper(player: player, templateItem: item)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				ZStack {
					ProgressView("Loading video")
						.progressViewStyle(.circular)
						.labelsHidden()
					VideoLayer(player: player)
						.onAppear {
							DispatchQueue.main.asyncAfter(deadline: .now()) {
								player.play()
							}
						}
						.onDisappear {
							player.pause()
							player.seek(to: .zero)
						}
						.onChange(of: environment.scenePhase) { newPhase in
							switch newPhase {
							case .active:
								player.play()
							default: break
							}
						}
				}
					.ignoresSafeArea()
					.frame(maxWidth: .greatestFiniteMagnitude, minHeight: (UIScreen.main.bounds.height - 96) * 0.9)
				Text("**1.** Long press in an empty spot on your Home Screen.")
				Text("**2.** Tap the \"+\" button in the top-left.")
				Text("**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it from the list.")
				Text("**4.** Swipe left to choose a size, then press the \"Add Widget\" button at the bottom.")//You can configure the Widget by tapping it while edit mode is active!")
				Text("Tip: If your photo library is sparse, the _On This Day_ Widget works best in a Smart Stack.\n\nDrag a system Photos Widget (with the same size) on top of this Widget to create a new Smart Stack. This lets _On This Day_ show at the top for days with photos, and otherwise the default Photos Widget will be shown as a fallback.")
					.italic()
				if inSheet {
					Button("Don't show again") {
						UserDefaults.standard.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
						dismiss()
					}
						.buttonStyle(.bordered)
						.frame(maxWidth: .greatestFiniteMagnitude)
				}
			}
				.onAppear {
					UIPasteboard.general.string = "On This Day"
				}
				.padding()
		}
			.navigationTitle("Add a Widget")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					if inSheet {
						ToolbarButtonView("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
			}
	}
}

struct HelpAddWidgetView_Previews: PreviewProvider {
	static var previews: some View {
		HelpAddWidgetView(inSheet: true)
	}
}
