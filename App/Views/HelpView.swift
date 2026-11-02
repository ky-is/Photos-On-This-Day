import SwiftUI

/// Answers to what people ask most, from the toolbar's More menu and the Help menu on a Mac.
struct HelpView: View {
	@Environment(\.dismiss) private var dismiss

	private struct Question {
		let question: LocalizedStringKey
		let answer: LocalizedStringKey
	}

	private let questions = [
		Question(question: "Why can’t I open a photo in the Photos app?", answer: "Apple doesn’t let apps open the Photos app to a particular photo, so there’s no way to jump from here to the same photo there. You can still favorite, share, hide or delete it right here in the viewer."),
		Question(question: "Why are some photos missing?", answer: Self.missingAnswer),
		Question(question: "How do I see another day?", answer: Self.dayAnswer),
		Question(question: "How do I change how often the widget changes photo?", answer: Self.widgetAnswer),
		Question(question: "Can I get a reminder every day?", answer: "Turn on Daily Reminder in the Filters menu for a notification each morning on days with photos from past years."),
		Question(question: "Can I see this year’s photos too, or the oldest first?", answer: "Turn on Show This Year or Oldest First in the Filters menu."),
		Question(question: "Does the app collect my data?", answer: "No. Your photos never leave your device. There’s no account, no tracking and no ads."),
	]

	#if os(macOS)
	private static let widgetAnswer: LocalizedStringKey = "Control-click the widget, choose Edit, and pick how often it changes. You can also add a button to shuffle to another photo."
	private static let dayAnswer: LocalizedStringKey = "Use the arrows or ⌘[ and ⌘], or click the calendar to pick any date."
	private static let missingAnswer: LocalizedStringKey = "Screenshots and photos shared with you in iCloud can be turned on in the Filters menu, and Hide Albums leaves out whole albums. Photos you hid from a day can be restored at the bottom of that day. If you gave the app access to only some of your photos, allow full access in System Settings."
	#else
	private static let dayAnswer: LocalizedStringKey = "Swipe left or right, use the arrows, or tap the calendar to pick any date."
	private static let missingAnswer: LocalizedStringKey = "Screenshots and photos shared with you in iCloud can be turned on in the Filters menu, and Hide Albums leaves out whole albums. Photos you hid from a day can be restored at the bottom of that day. If you gave the app access to only some of your photos, allow full access in Settings."
	private static let widgetAnswer: LocalizedStringKey = "Touch and hold the widget, choose Edit Widget, and pick how often it changes. You can also add a button to shuffle to another photo."
	#endif

	var body: some View {
		NavigationStack {
			Form {
				Section {
					ForEach(questions.indices, id: \.self) { index in
						let item = questions[index]
						DisclosureGroup {
							Text(item.answer)
								.foregroundStyle(.secondary)
						} label: {
							Text(item.question)
						}
					}
				}
				Section {
					NavigationLink("How to add a Widget") {
						HelpAddWidgetView(inSheet: false)
					}
					Link(destination: URL(string: "https://onthisday.ky.is/support/")!) {
						HStack {
							Text("More Help")
							Image(systemName: "arrow.up.forward.square")
								.accessibilityHidden(true)
						}
					}
				}
			}
				.navigationTitle("Help")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						ToolbarButtonView("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
				#if os(macOS)
				.frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 640)
				#endif
		}
	}
}

#Preview {
	HelpView()
}
