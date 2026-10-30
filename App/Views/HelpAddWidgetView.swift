import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss

	@AppStorage(UserDefaults.Key.dismissedAddWidget) private var dismissedAddWidget = false

	#if os(macOS)
	private static let iconName = "widget.small.badge.plus"
	#else
	private static let iconName = "apps.iphone.badge.plus"
	#endif

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Image(systemName: Self.iconName)
					.font(.system(size: 72))
					.foregroundStyle(.tint)
					.frame(maxWidth: .infinity)
					.padding(.vertical)
				#if os(macOS)
				Text("**1.** Control-click an empty spot on your desktop and choose **Edit Widgets**.")
				Text("**2.** Search for \"On This Day\" (it's been copied to your clipboard), or find it in the list.")
				Text("**3.** Choose a size, then drag the widget onto your desktop or into Notification Center.")
				Text("To choose which years it shows, or only show favorites, Control-click the widget and choose **Edit \"On This Day\"**.")
				#else
				Text("**1.** Touch and hold an empty spot on your Home Screen until the apps jiggle.")
				Text("**2.** Tap **Edit** in the top-left corner, then **Add Widget**.")
				Text("**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it in the list.")
				Text("**4.** Swipe to choose a size, then tap **Add Widget**.")
				Text("To choose which years it shows, or only show favorites, touch and hold the widget and tap **Edit Widget**.")
				// Smart Stacks are only on iPhone and iPad.
				Group {
					Text("Tip: If your photo library is sparse, the _On This Day_ widget works best in a Smart Stack.")
					Text("Drag a Photos widget of the same size on top of this widget to create a Smart Stack. _On This Day_ then shows on days with photos, and the Photos widget shows otherwise.")
				}
					.font(.callout)
					.foregroundStyle(.secondary)
				#endif
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
				Pasteboard.copy("On This Day")
			}
			.navigationTitle("Add a Widget")
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

#Preview {
	NavigationStack {
		HelpAddWidgetView(inSheet: true)
	}
}
