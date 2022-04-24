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
				Text("**3.** Search for \"On This Day\" or find it in the list.")
				Text("**4.** Swipe left to choose a size, then press the \"Add Widget\" button at the bottom.")//You can configure the Widget by tapping it while edit mode is active!")
			}
				.padding()
		}
			.navigationTitle("Add a Widget")
			.toolbar {
				ToolbarItem(placement: .destructiveAction) {
					if inSheet {
						Button("Don't show again") {
							UserDefaults.shared.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
							dismiss()
						}
					}
				}
				ToolbarItem(placement: .cancellationAction) {
					if inSheet {
						Button("Close") {
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
