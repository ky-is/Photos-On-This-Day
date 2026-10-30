import Foundation
import Testing
@testable import Photos_On_This_Day

private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
	Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

private func photos(on date: Date, count: Int, favorites: Int = 0) -> [OccasionPhoto] {
	(0..<count).map { OccasionPhoto(created: date, isFavorite: $0 < favorites) }
}

struct OccasionPickerTests {
	@Test func picksTheDayWithTheMostPhotos() throws {
		let all = photos(on: day(2017, 6, 7), count: 3) + photos(on: day(2017, 8, 1), count: 5)
		let occasion = try #require(OccasionPicker.best(photos: all, from: day(2027, 1, 1)))
		#expect(occasion == Occasion(day: day(2027, 8, 1, hour: 0), yearsAgo: 10, photoCount: 5))
	}

	@Test func onlyRoundAnniversariesCount() {
		let all = photos(on: day(2019, 6, 7), count: 10)
		#expect(OccasionPicker.best(photos: all, from: day(2027, 1, 1)) == nil)
	}

	@Test func needsEnoughPhotos() {
		#expect(OccasionPicker.best(photos: photos(on: day(2017, 6, 7), count: 2), from: day(2027, 1, 1)) == nil)
	}

	@Test func aFavoriteIsEnough() {
		#expect(OccasionPicker.best(photos: photos(on: day(2017, 6, 7), count: 1, favorites: 1), from: day(2027, 1, 1))?.photoCount == 1)
	}

	@Test func ignoresDaysOutsideTheYear() {
		let all = photos(on: day(2016, 12, 31), count: 5) + photos(on: day(2018, 1, 1), count: 5)
		#expect(OccasionPicker.best(photos: all, from: day(2027, 1, 1)) == nil)
	}

	@Test func tiesGoToTheBiggerMilestone() throws {
		let all = photos(on: day(2017, 6, 7), count: 4) + photos(on: day(2007, 9, 1), count: 4)
		#expect(try #require(OccasionPicker.best(photos: all, from: day(2027, 1, 1))).yearsAgo == 20)
	}

	@Test func searchRangesCoverEachMilestoneYear() throws {
		let ranges = OccasionPicker.searchRanges(from: day(2027, 3, 15))
		let first = try #require(ranges.first)
		#expect(first.lowerBound == day(2022, 3, 15, hour: 0))
		#expect(first.upperBound == day(2023, 3, 15, hour: 0))
		#expect(ranges.count == OccasionPicker.milestones.count)
	}

	/// The reminder looks a couple of months ahead and falls back to any year when no round anniversary is in reach.
	@Test func aShortWindowCanUseAnyYear() throws {
		let all = photos(on: day(2019, 3, 1), count: 4)
		let anyYear = Array(1...maxYearsBack)
		#expect(try #require(OccasionPicker.best(photos: all, from: day(2027, 2, 1), days: 60, yearsAgo: anyYear)).yearsAgo == 8)
		// March 1 is outside the 60 days from June 1.
		#expect(OccasionPicker.best(photos: all, from: day(2027, 6, 1), days: 60, yearsAgo: anyYear) == nil)
	}

	@Test func shortRangesSpanTheWindow() throws {
		let range = try #require(OccasionPicker.searchRanges(from: day(2027, 3, 15), days: 60, yearsAgo: [1]).first)
		#expect(range.lowerBound == day(2026, 3, 15, hour: 0))
		#expect(range.upperBound == day(2026, 5, 14, hour: 0))
	}
}
