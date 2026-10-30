import AppIntents
import WidgetKit

/// The widget's shuffle button. WidgetKit reloads the widget after it runs, and the new timeline skips the photo that was showing.
struct ShufflePhotoIntent: AppIntent {
	static let title: LocalizedStringResource = "Shuffle Photo"
	static let isDiscoverable = false

	@Parameter(title: "Current Photo")
	var currentID: String?

	init() {}

	init(currentID: String?) {
		self.currentID = currentID
	}

	func perform() async throws -> some IntentResult {
		UserDefaults.shared.widgetShuffledPhotoID = currentID
		return .result()
	}
}
