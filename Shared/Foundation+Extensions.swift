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
		// A fixed day for the simulator's sample library; `-screenshotDate 2022-08-08T18:00:00Z` picks another. Widgets get the
		// app's through the app group (ScreenshotSupport), since launch arguments only reach the app.
		let isWidget = Bundle.main.bundleURL.pathExtension == "appex"
		let date = UserDefaults.standard.string(forKey: "screenshotDate") ?? (isWidget ? UserDefaults.shared.string(forKey: "screenshotDate") : nil) ?? "2022-06-07T18:00:00Z"
		return (try? Date(date, strategy: .iso8601)) ?? Date()
#elseif DEBUG && os(macOS)
		// The Mac screenshots' day (bin/mac-screenshots.zsh), with `-screenshotDate`
		UserDefaults.standard.string(forKey: "screenshotDate").flatMap { try? Date($0, strategy: .iso8601) } ?? Date()
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
