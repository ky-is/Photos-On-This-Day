import Foundation

extension Bundle {
	var versionName: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
	}

	var versionNumber: Int {
		guard let string = object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String else { return 0 }
		return Int(string) ?? 0
	}
}

extension Date {
	static func current() -> Self {
#if targetEnvironment(simulator)
		return try! Date("2022-06-07T18:00:00Z", strategy: .iso8601)
#else
		return Date()
#endif
	}

	func getStartAndEndOfDay() -> (startDate: Date, endDate: Date) {
		let calendar = Calendar.current
		let startDate = calendar.startOfDay(for: self)
		let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: self)!)
		return (startDate, endDate)
	}
}

extension DateFormatter {
	static let monthDay: DateFormatter = {
		let currentLocale: Locale = Locale.current
		let dateComponents = "MMMMd"
		let dateFormat = DateFormatter.dateFormat(fromTemplate: dateComponents, options: 0, locale: currentLocale)
		let formatter = DateFormatter()
		formatter.dateFormat = dateFormat
		return formatter
	}()
}

extension String {
	func pluralized(_ count: Int) -> String {
		return count == 1 ? self : "\(self)s"
	}

	func pluralize(_ count: Int) -> String {
		return "\(count) \(pluralized(count))"
	}
}

extension TimeInterval {
	static let second: Self = 1
	static let minute = .second * 60
	static let hour = .minute * 60
	static let day = .hour * 24
}

extension Calendar {
	func getDateID(from date: Date) -> String {
		return "\(component(.month, from: date))-\(component(.day, from: date))"
	}
}
