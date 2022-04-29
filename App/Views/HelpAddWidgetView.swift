import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss

	@State private var loading = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("**1.** Long press in an empty spot on your Home Screen.")
				Text("**2.** Tap the \"+\" button in the top-left.")
				Text("**3.** Search for \"On This Day\" (it's been copied to your clipboard), or find it from the list.")
				Text("**4.** Swipe left to choose a size, then press the \"Add Widget\" button at the bottom.")//You can configure the Widget by tapping it while edit mode is active!")
				Text("Tip: If your photo library is sparse, the _On This Day_ Widget works best in a Smart Stack. Drag a system Photos Widget (with the same size) on top of this Widget to create a new Smart Stack. This lets _On This Day_ show at the top for days with photos, and otherwise the default Photos Widget will be shown as a fallback.")
					.italic()
					.padding()
					.multilineTextAlignment(.center)
			}
				.onAppear {
					UIPasteboard.general.string = "On This Day"
				}
				.padding()
		}
			.navigationTitle("Add a Widget")
			.toolbar {
				ToolbarItem(placement: .destructiveAction) {
					if inSheet {
						ToolbarButton("Don't show again") {
							UserDefaults.standard.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
							dismiss()
						}
					}
				}
				ToolbarItem(placement: .cancellationAction) {
					if inSheet {
						ToolbarButton("Close") {
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
