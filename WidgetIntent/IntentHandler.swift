import Intents

final class IntentHandler: INExtension, ConfigurationIntentHandling {
	func provideOnlyShowYearsOptionsCollection(for intent: ConfigurationIntent) async throws -> INObjectCollection<YearType> {
		let currentYear = Calendar.current.component(.year, from: Date())
		let items: [YearType] = (1..<100).map { yearsAgo in
			let yearDescription = (currentYear - yearsAgo).description
			let yearType = YearType(identifier: yearDescription, display: yearDescription)
			yearType.yearsAgo = NSNumber(integerLiteral: yearsAgo)
			return yearType
		}
		return INObjectCollection(items: items)
	}
}
