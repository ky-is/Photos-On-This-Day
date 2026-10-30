import AppIntents

/// A past year, for widget settings and Siri.
nonisolated struct YearEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Year"
	static let defaultQuery = YearQuery()

	/// The year, e.g. "2021".
	let id: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(id)")
	}
}

nonisolated struct YearQuery: EntityStringQuery {
	func entities(for identifiers: [String]) async throws -> [YearEntity] {
		identifiers.map(YearEntity.init)
	}

	/// Typed years, e.g. "2018" in Shortcuts.
	func entities(matching string: String) async throws -> [YearEntity] {
		guard let year = Int(string.trimmingCharacters(in: .whitespaces)), (1..<100).contains(Date.current().year - year) else { return [] }
		return [YearEntity(id: String(year))]
	}

	func suggestedEntities() async throws -> [YearEntity] {
		let currentYear = Date.current().year
		return (1..<100).map { YearEntity(id: String(currentYear - $0)) }
	}
}
