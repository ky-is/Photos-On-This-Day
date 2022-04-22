import Foundation

extension Date {
	func getStartAndEndOfDay() -> (startDate: Date, endDate: Date) {
		let calendar = Calendar.current
		let startDate = calendar.startOfDay(for: self)
		let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: self)!)
		return (startDate, endDate)
	}
}
