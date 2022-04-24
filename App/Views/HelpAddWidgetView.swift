import SwiftUI

struct HelpAddWidgetView: View {
	let inSheet: Bool

	@Environment(\.dismiss) private var dismiss

	@State private var loading = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading) {
				Text("1.  Long press in an empty spot on your Home Screen.")
				Text("2.  Tap the \"+\" button in the top-left.")
				Text("3.  Search for \"On This Day\" or find it in the list.")
				Text("4.  Choose a size. You can configure the widget by tapping it while edit mode is active!")
			}
				.padding(8)
		}
			.navigationTitle("Add a Widget")
			.toolbar {
				ToolbarItem(placement: .destructiveAction) {
					if inSheet {
						Button("Don't show again") {
							UserDefaults.standard.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
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
