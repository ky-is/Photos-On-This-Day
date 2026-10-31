import AppIntents
import Photos

/// Opens the app to a day's photos from past years.
struct OpenDayIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Photos On This Day"
	static let description = IntentDescription("Opens your photos from past years on today, or on another date.")
	static let supportedModes: IntentModes = .foreground

	@Parameter(title: "Date", description: "Leave empty for today.", kind: .date)
	var date: Date?

	static var parameterSummary: some ParameterSummary {
		Summary("Show photos on \(\.$date)")
	}

	@MainActor func perform() async throws -> some IntentResult {
		let state = StateManager.shared
		state.refresh()
		state.openedPhoto = nil
		state.go(to: date ?? Date.current())
		return .result()
	}
}

/// Opens a random photo from past years on today.
struct OpenRandomMemoryIntent: AppIntent {
	static let title: LocalizedStringResource = "Show a Random Memory"
	static let description = IntentDescription("Opens a random photo taken on this day in a past year.")
	static let supportedModes: IntentModes = .foreground

	@MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
		if let photoDate = await StateManager.shared.openRandomPhoto(on: Date.current())?.creationDate {
			return .result(dialog: "Here's one from \(String(photoDate.year)).")
		}
		return .result(dialog: "There are no photos from past years on this day.")
	}
}

/// Opens today's photos from a chosen past year.
struct OpenYearIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Photos From a Year"
	static let description = IntentDescription("Opens the photos you took on this day in the year you choose.")
	static let supportedModes: IntentModes = .foreground

	@Parameter(title: "Year")
	var year: YearEntity

	static var parameterSummary: some ParameterSummary {
		Summary("Show photos from \(\.$year)")
	}

	@MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
		if let number = Int(year.id), await StateManager.shared.openPhoto(fromYear: number) != nil {
			return .result(dialog: "Here are your photos from \(year.id).")
		}
		return .result(dialog: "There are no photos from \(year.id) on this day.")
	}
}

/// Says how many photos there are from past years on a day, without opening the app.
struct CountPhotosIntent: AppIntent {
	static let title: LocalizedStringResource = "Count Photos On This Day"
	static let description = IntentDescription("How many photos you took on this day in past years.")

	@Parameter(title: "Date", description: "Leave empty for today.", kind: .date)
	var date: Date?

	static var parameterSummary: some ParameterSummary {
		Summary("Count photos on \(\.$date)")
	}

	@MainActor func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
		let state = StateManager.shared
		state.refresh()
		guard state.canShowPhotos else {
			return .result(value: 0, dialog: "Open the app first to allow access to your photos.")
		}
		let day = date ?? Date.current()
		let assets = await state.pastYearAssets(on: day)
		let years = Set(assets.compactMap { $0.creationDate?.year }).count
		let text = assets.isEmpty ? String(localized: "There are no photos from past years on this day.") : String(AttributedString(localized: "^[\(assets.count) photo](inflect: true) from ^[\(years) year](inflect: true) on this day.").characters)
		return .result(value: assets.count, dialog: "\(text)")
	}
}

struct PhotosOnThisDayShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		AppShortcut(intent: OpenDayIntent(), phrases: [
			"Show \(.applicationName)",
			"Open \(.applicationName)",
		], shortTitle: "Photos On This Day", systemImageName: "calendar")
		AppShortcut(intent: OpenRandomMemoryIntent(), phrases: [
			"Show a random memory in \(.applicationName)",
			"Surprise me with \(.applicationName)",
		], shortTitle: "Random Memory", systemImageName: "shuffle")
		AppShortcut(intent: OpenYearIntent(), phrases: [
			"Show photos from \(\.$year) in \(.applicationName)",
			"Show \(\.$year) in \(.applicationName)",
		], shortTitle: "Photos From a Year", systemImageName: "calendar.badge.clock")
		AppShortcut(intent: CountPhotosIntent(), phrases: [
			"How many photos are in \(.applicationName)",
			"Count photos in \(.applicationName)",
		], shortTitle: "Count Photos", systemImageName: "number")
	}
}
