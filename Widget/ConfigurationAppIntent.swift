import AppIntents
import WidgetKit

/// Replaces the SiriKit `ConfigurationIntent`; existing widgets migrate their settings by parameter name.
struct ConfigurationAppIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "ConfigurationIntent"
	static let title: LocalizedStringResource = "Configuration"

	@Parameter(title: "Only show Favorites", default: false)
	var onlyShowFavorites: Bool

	@Parameter(title: "Only show selected years")
	var onlyShowYears: [YearEntity]?

	/// Years back from `date` to show photos from.
	nonisolated func yearDiffs(from date: Date) -> [Int] {
		DayMath.yearDiffs(selectedYears: (onlyShowYears ?? []).map(\.id), from: date)
	}
}

nonisolated struct YearEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Year"
	static let defaultQuery = YearQuery()

	/// The year, e.g. "2021".
	let id: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(id)")
	}
}

nonisolated struct YearQuery: EntityQuery {
	func entities(for identifiers: [String]) async throws -> [YearEntity] {
		identifiers.map(YearEntity.init)
	}

	func suggestedEntities() async throws -> [YearEntity] {
		let currentYear = Date.current().year
		return (1..<100).map { YearEntity(id: String(currentYear - $0)) }
	}
}
