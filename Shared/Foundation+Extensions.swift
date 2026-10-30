import Foundation

nonisolated extension Bundle {
	var versionName: String {
		object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
	}

	var versionNumber: Int {
		Int(object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "") ?? 0
	}
}

nonisolated extension Date {
	static func current() -> Self {
#if targetEnvironment(simulator)
		try! Date("2022-06-07T18:00:00Z", strategy: .iso8601)
#else
		Date()
#endif
	}

	var startAndEndOfDay: (start: Date, end: Date) {
		let calendar = Calendar.current
		let start = calendar.startOfDay(for: self)
		return (start, calendar.date(byAdding: .day, value: 1, to: start)!)
	}

	var year: Int {
		Calendar.current.component(.year, from: self)
	}

	/// Identifies a day of the year (month and day), shared across years.
	var dateID: String {
		let components = Calendar.current.dateComponents([.month, .day], from: self)
		return "\(components.month!)-\(components.day!)"
	}
}

nonisolated extension FormatStyle where Self == Date.FormatStyle {
	static var monthDay: Self {
		.dateTime.month(.wide).day()
	}
}
