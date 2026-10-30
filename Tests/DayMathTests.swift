import Foundation
import Testing
@testable import Photos_On_This_Day

private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
	Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

struct DateIDTests {
	@Test func monthAndDayWithoutPadding() {
		#expect(day(2022, 3, 30).dateID == "3-30")
		#expect(day(2022, 12, 1).dateID == "12-1")
	}

	@Test func sameDayInDifferentYearsMatches() {
		#expect(day(2018, 6, 7).dateID == day(2022, 6, 7, hour: 23).dateID)
	}

	@Test func roundTripsThroughDate() throws {
		let date = try #require(DayMath.date(fromDateID: "3-30"))
		#expect(date.dateID == "3-30")
	}

	@Test func leapDayParses() {
		#expect(DayMath.date(fromDateID: "2-29")?.dateID == "2-29")
	}

	@Test(arguments: ["", "3", "13-1", "2-30", "a-b", "1-2-3"])
	func invalidIDsDoNotParse(_ dateID: String) {
		#expect(DayMath.date(fromDateID: dateID) == nil)
	}

	@Test func hiddenDaysSortInCalendarOrder() {
		let sorted = ["12-25", "9-1", "1-5", "10-3"].sorted { DayMath.date(fromDateID: $0)! < DayMath.date(fromDateID: $1)! }
		#expect(sorted == ["1-5", "9-1", "10-3", "12-25"])
	}
}

struct DayRangeTests {
	@Test func coversExactlyOneDay() {
		let (start, end) = day(2022, 6, 7, hour: 18).startAndEndOfDay
		#expect(start == Calendar.current.startOfDay(for: day(2022, 6, 7)))
		#expect(end == Calendar.current.startOfDay(for: day(2022, 6, 8)))
	}

	@Test func yearIsTheCalendarYear() {
		#expect(day(2021, 12, 31, hour: 23).year == 2021)
		#expect(day(2022, 1, 1, hour: 0).year == 2022)
	}
}

struct NearestDayTests {
	@Test func findsClosestEarlierDay() {
		let ids: Set = [day(2022, 5, 1).dateID, day(2022, 3, 30).dateID]
		#expect(DayMath.nearestDaysBack(from: day(2022, 6, 7), toAnyOf: ids) == 37)
	}

	@Test func ignoresTheStartingDay() {
		let ids: Set = [day(2022, 6, 7).dateID]
		#expect(DayMath.nearestDaysBack(from: day(2022, 6, 7), toAnyOf: ids) == 365)
	}

	@Test func wrapsAcrossNewYear() {
		let ids: Set = [day(2021, 12, 30).dateID]
		#expect(DayMath.nearestDaysBack(from: day(2022, 1, 2), toAnyOf: ids) == 3)
	}

	@Test func nothingFound() {
		#expect(DayMath.nearestDaysBack(from: day(2022, 6, 7), toAnyOf: []) == nil)
	}
}

struct YearDiffTests {
	@Test func selectedYearsAreAbsolute() {
		#expect(DayMath.yearDiffs(selectedYears: ["2021", "2018"], from: day(2026, 10, 30)) == [5, 8])
	}

	@Test func ignoresCurrentFutureAndInvalidYears() {
		#expect(DayMath.yearDiffs(selectedYears: ["2026", "2030", "abc"], from: day(2026, 10, 30)) == Array(1...maxYearsBack))
	}

	@Test func noSelectionMeansAllYears() {
		#expect(DayMath.yearDiffs(selectedYears: [], from: day(2026, 10, 30)) == Array(1...maxYearsBack))
	}
}

struct RoundRobinTests {
	@Test func alternatesBetweenLists() {
		#expect(DayMath.roundRobin([[1, 2, 3], [10, 20], [100]], limit: 10) == [1, 10, 100, 2, 20, 3])
	}

	@Test func stopsAtLimitMidRound() {
		#expect(DayMath.roundRobin([[1, 2], [10, 20]], limit: 3) == [1, 10, 2])
	}

	@Test func emptyLists() {
		#expect(DayMath.roundRobin([[Int](), []], limit: 5).isEmpty)
		#expect(DayMath.roundRobin([[Int]](), limit: 5).isEmpty)
	}
}

struct DeepLinkTests {
	@Test func photoLinkRoundTrips() {
		let id = "0027E47F-8A12-4D8F-9CA5-F9891C5BA792/L0/001"
		#expect(DeepLink.photoID(from: DeepLink.photo(id: id)) == id)
	}

	@Test func ignoresOtherLinks() {
		#expect(DeepLink.photoID(from: URL(string: "https://example.com/photo?id=1")!) == nil)
		#expect(DeepLink.photoID(from: URL(string: "photosonthisday://day?id=1")!) == nil)
		#expect(DeepLink.photoID(from: URL(string: "photosonthisday://photo")!) == nil)
	}
}
