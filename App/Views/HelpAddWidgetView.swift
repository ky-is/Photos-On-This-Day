import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss

	@AppStorage(UserDefaults.Key.dismissedAddWidget) private var dismissedAddWidget = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Image(systemName: "apps.iphone.badge.plus")
					.font(.system(size: 72))
					.foregroundStyle(.tint)
					.frame(maxWidth: .infinity)
					.padding(.vertical)
				Text("**1.** Touch and hold an empty spot on your Home Screen until the apps jiggle.")
				Text("**2.** Tap **Edit** in the top-left corner, then **Add Widget**.")
				Text("**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it in the list.")
				Text("**4.** Swipe to choose a size, then tap **Add Widget**.")
				Text("To choose which years it shows, or only show favorites, touch and hold the widget and tap **Edit Widget**.")
				Group {
					Text("Tip: If your photo library is sparse, the _On This Day_ widget works best in a Smart Stack.")
					Text("Drag a Photos widget of the same size on top of this widget to create a Smart Stack. _On This Day_ then shows on days with photos, and the Photos widget shows otherwise.")
				}
					.font(.callout)
					.foregroundStyle(.secondary)
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
	NavigationStack {
		HelpAddWidgetView(inSheet: true)
	}
}
