import AppIntents
import WidgetKit

/// Settings for the photo widget. Replaces the SiriKit `ConfigurationIntent`; existing widgets migrate their settings by parameter name.
struct ConfigurationAppIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "ConfigurationIntent"
	static let title: LocalizedStringResource = "Configuration"

	@Parameter(title: "Only show Favorites", default: false)
	var onlyShowFavorites: Bool

	@Parameter(title: "Only show selected years")
	var onlyShowYears: [YearEntity]?

	@Parameter(title: "Change Photo", default: .every30Minutes)
	var updateFrequency: UpdateFrequency

	@Parameter(title: "Show Shuffle Button", default: true)
	var showShuffleButton: Bool

	/// Years back from `date` to show photos from.
	nonisolated func yearDiffs(from date: Date) -> [Int] {
		DayMath.yearDiffs(selectedYears: (onlyShowYears ?? []).map(\.id), from: date)
	}
}

/// Settings for the Years widget.
struct YearsConfigurationAppIntent: WidgetConfigurationIntent {
	static let title: LocalizedStringResource = "Years"

	@Parameter(title: "Only show Favorites", default: false)
	var onlyShowFavorites: Bool

	@Parameter(title: "Only show selected years")
	var onlyShowYears: [YearEntity]?

	@Parameter(title: "Change Photos", default: .every3Hours)
	var updateFrequency: UpdateFrequency

	/// Years back from `date` to show photos from.
	nonisolated func yearDiffs(from date: Date) -> [Int] {
		DayMath.yearDiffs(selectedYears: (onlyShowYears ?? []).map(\.id), from: date)
	}
}

/// How often a widget switches to other photos from the day.
nonisolated enum UpdateFrequency: String, AppEnum {
	case every30Minutes
	case hourly
	case every3Hours
	case every6Hours
	case daily

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Frequency"
	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.every30Minutes: "Every 30 Minutes",
		.hourly: "Every Hour",
		.every3Hours: "Every 3 Hours",
		.every6Hours: "Every 6 Hours",
		.daily: "Once a Day",
	]

	var interval: TimeInterval {
		switch self {
		case .every30Minutes: 30 * 60
		case .hourly: 60 * 60
		case .every3Hours: 3 * 60 * 60
		case .every6Hours: 6 * 60 * 60
		case .daily: 24 * 60 * 60
		}
	}

	/// How many changes fit between now and `end`, at least one.
	func slots(until end: Date, from start: Date) -> Int {
		max(1, Int((end.timeIntervalSince(start) / interval).rounded(.up)))
	}
}
