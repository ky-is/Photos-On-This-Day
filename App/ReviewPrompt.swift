import StoreKit
import SwiftUI
import WidgetKit

extension View {
	/// Asks for an App Store rating when the photo viewer closes, with a widget added, at most once a day.
	func reviewPrompt() -> some View {
		modifier(ReviewPrompt())
	}
}

/// Most people live with the widget and rarely open the app, so every visit is a chance to ask, once they've added one
/// (by then they've seen what it does), right after they've looked at a photo. The system decides whether the prompt
/// actually shows: at most three times a year, and never once they've rated.
struct ReviewPrompt: ViewModifier {
	/// Whether to ask: with a widget added, and not twice in a day.
	static func shouldAsk(today: String, lastAsked: String, hasWidget: Bool) -> Bool {
		hasWidget && today != lastAsked
	}

	@Environment(\.requestReview) private var requestReview
	@AppStorage("reviewLastAsked", store: .standard) private var lastAsked = ""

	private var state = StateManager.shared

	func body(content: Content) -> some View {
		content
			.onChange(of: state.openedPhoto == nil) { _, closed in
				let today = Date.now.formatted(date: .numeric, time: .omitted)
				guard closed, !Self.isScreenshot, today != lastAsked else { return }
				Task {
					let hasWidget = (try? await WidgetCenter.shared.currentConfigurations().isEmpty) == false
					guard Self.shouldAsk(today: today, lastAsked: lastAsked, hasWidget: hasWidget) else { return }
					lastAsked = today
					// Once the viewer has finished closing
					try? await Task.sleep(for: .seconds(1))
					requestReview()
				}
			}
	}

	/// App Store screenshots and UI tests never see it.
	private static var isScreenshot: Bool {
		UserDefaults.standard.string(forKey: "screenshotDate") != nil
	}
}
