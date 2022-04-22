import Foundation

extension Date {
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
