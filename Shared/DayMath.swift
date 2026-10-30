import Foundation

/// Date and selection logic shared by the app and widget, kept free of Photos so it can be tested.
nonisolated enum DayMath {
	/// A leap year, so a `dateID` of February 29 still makes a valid date.
	static let referenceYear = 2000

	/// The calendar date for a `Date.dateID` ("month-day"), in `referenceYear`.
	static func date(fromDateID dateID: String, calendar: Calendar = .current) -> Date? {
		let parts = dateID.split(separator: "-").compactMap { Int($0) }
		guard parts.count == 2 else { return nil }
		let components = DateComponents(year: referenceYear, month: parts[0], day: parts[1])
		guard components.isValidDate(in: calendar) else { return nil }
		return calendar.date(from: components)
	}

	/// How many days back from `date` the nearest day is whose `dateID` is in `dayIDs`, looking up to a year back.
	static func nearestDaysBack(from date: Date, toAnyOf dayIDs: Set<String>, calendar: Calendar = .current) -> Int? {
		(1...365).first { daysBack in
			dayIDs.contains(calendar.date(byAdding: .day, value: -daysBack, to: date)!.dateID)
		}
	}

	/// Years back from `date` for the widget's selected years (as strings like "2021"), or every year up to `maxYearsBack` when none apply.
	static func yearDiffs(selectedYears: [String], from date: Date) -> [Int] {
		let currentYear = date.year
		let selected = selectedYears.compactMap { Int($0).map { currentYear - $0 } }.filter { $0 > 0 }
		return selected.isEmpty ? Array(1...maxYearsBack) : selected
	}

	/// Takes one item from each list in turn until `limit` items are taken or the lists run out.
	static func roundRobin<Element>(_ lists: [[Element]], limit: Int) -> [Element] {
		var results: [Element] = []
		var iterators = lists.map { $0.makeIterator() }
		while results.count < limit {
			var foundAny = false
			for index in iterators.indices {
				guard results.count < limit else { break }
				if let next = iterators[index].next() {
					results.append(next)
					foundAny = true
				}
			}
			if !foundAny {
				break
			}
		}
		return results
	}
}
