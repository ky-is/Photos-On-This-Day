import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var step = 0
	@State private var beat = 0
	/// Goes up when a step is tapped, to play from there
	@State private var restart = 0

	#if os(macOS)
	private static let steps: [LocalizedStringKey] = [
		"**1.** Control-click an empty spot on your desktop and choose **Edit Widgets**.",
		"**2.** Search for \"On This Day\" (it's been copied to your clipboard), or find it in the list.",
		"**3.** Choose a size, then drag the widget onto your desktop or into Notification Center.",
	]
	#else
	private static let steps: [LocalizedStringKey] = [
		"**1.** Touch and hold an empty spot on your Home Screen until the apps jiggle.",
		"**2.** Tap **Edit** in the top-left corner, then **Add Widget**.",
		"**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it in the list.",
		"**4.** Swipe to choose a size, then tap **Add Widget**.",
	]
	#endif

	var body: some View {
		VStack(spacing: 0) {
			// Stays at the top while the steps scroll under it
			AddWidgetAnimation(step: step, beat: beat)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)
				#if os(iOS)
				.padding(.top, 8)
				#endif
				.accessibilityHidden(true)
			Divider()
			ScrollView {
				VStack(alignment: .leading, spacing: 4) {
					ForEach(Self.steps.indices, id: \.self) { index in
						Button {
							step = index
							beat = 0
							restart += 1
						} label: {
							Text(Self.steps[index])
								.multilineTextAlignment(.leading)
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(10)
								.background(index == step ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
								.contentShape(.rect)
						}
							.buttonStyle(.plain)
							.padding(.horizontal, -10)
							.accessibilityAddTraits(index == step ? .isSelected : [])
					}
					VStack(alignment: .leading, spacing: 16) {
						#if os(macOS)
						Text("To choose which years it shows, or only show favorites, Control-click the widget and choose **Edit \"On This Day\"**.")
						#else
						Text("To choose which years it shows, or only show favorites, touch and hold the widget and tap **Edit Widget**.")
						// Smart Stacks are only on iPhone and iPad.
						Group {
							Text("Tip: If your photo library is sparse, the _On This Day_ widget works best in a Smart Stack.")
							Text("Drag a Photos widget of the same size on top of this widget to create a Smart Stack. _On This Day_ then shows on days with photos, and the Photos widget shows otherwise.")
						}
							.font(.callout)
							.secondaryTextStyle()
						#endif
					}
						.padding(.top, 12)
				}
					.padding()
			}
		}
			#if os(iOS)
			// The animation rises into the bar, which is clear so it shows through. The bar's buttons sit to the side of the phone.
			.ignoresSafeArea(.container, edges: .top)
			.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
			#endif
			.onAppear {
				Pasteboard.copy("On This Day")
			}
			.task(id: restart) {
				await play()
			}
			.inlineNavigationTitle()
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

extension HelpAddWidgetView {
	/// Plays the steps in a loop, from the one showing
	private func play() async {
		var index = step
		while !Task.isCancelled {
			for (beatIndex, seconds) in AddWidgetAnimation.beats[index].enumerated() {
				withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .smooth(duration: 0.5)) {
					step = index
					beat = beatIndex
				}
				try? await Task.sleep(for: .seconds(seconds))
				if Task.isCancelled { return }
			}
			index = (index + 1) % AddWidgetAnimation.beats.count
		}
	}
}

#Preview {
	NavigationStack {
		HelpAddWidgetView(inSheet: true)
	}
}
