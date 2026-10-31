import Testing
@testable import Photos_On_This_Day

struct CollageLayoutTests {
	/// Every row adds up to the full width.
	private func expectFull(_ layout: CollageLayout) {
		for row in layout.rows {
			#expect(row.reduce(0) { $0 + $1.span } == layout.columns)
		}
	}

	@Test func threeYearsBorrowAPhotoToFillTwoByTwo() {
		let layout = CollageLayout(counts: [1, 5, 2])
		#expect(layout.columns == 2)
		#expect(layout.rows.flatMap { $0 }.count == 4)
		// The year with the most to spare gives the extra photo.
		#expect(layout.rows.flatMap { $0 }.filter { $0.year == 1 }.count == 2)
		expectFull(layout)
	}

	@Test func sevenYearsFillThreeByThree() {
		let layout = CollageLayout(counts: [3, 1, 1, 2, 1, 1, 1])
		#expect(layout.columns == 3)
		#expect(layout.rows.count == 3)
		#expect(layout.rows.flatMap { $0 }.allSatisfy { $0.span == 1 })
		expectFull(layout)
	}

	@Test func twoYearsMakeASquareWhenTheyCan() {
		let layout = CollageLayout(counts: [3, 2])
		#expect(layout.rows.count == 2)
		expectFull(layout)
	}

	@Test func tooFewPhotosWidenTheLastRow() {
		let layout = CollageLayout(counts: [1, 1, 1, 1, 1])
		#expect(layout.columns == 3)
		#expect(layout.rows.last?.map(\.span) == [2, 1])
		expectFull(layout)
	}

	@Test func oneYearWithManyPhotos() {
		let layout = CollageLayout(counts: [6])
		#expect(layout.rows.flatMap { $0 }.count == 4)
		expectFull(layout)
	}

	@Test func onePhoto() {
		let layout = CollageLayout(counts: [1])
		#expect(layout.columns == 1)
		expectFull(layout)
	}
}

struct CollageStoryLayoutTests {
	@Test func storyUsesTwoColumnsForSixYears() {
		let layout = CollageLayout(counts: [1, 1, 1, 1, 1, 1], format: .story)
		#expect(layout.columns == 2)
		#expect(layout.rows.count == 3)
	}

	@Test func storyAddsAThirdRowWhenThereArePhotos() {
		let layout = CollageLayout(counts: [4, 3], format: .story)
		#expect(layout.rows.count == 3)
		#expect(layout.rows.flatMap { $0 }.count == 6)
	}

	@Test func storyWithManyYearsUsesThreeColumns() {
		let layout = CollageLayout(counts: Array(repeating: 2, count: 8), format: .story)
		#expect(layout.columns == 3)
		#expect(layout.rows.count == 3)
		#expect(layout.rows.allSatisfy { $0.reduce(0) { $0 + $1.span } == 3 })
	}
}
