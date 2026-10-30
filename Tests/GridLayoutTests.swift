import CoreGraphics
import Testing
@testable import Photos_On_This_Day

struct GridLayoutTests {
	/// 3 columns on a 402pt iPhone: years with 2, 5 and 1 photos.
	let layout = GridLayout(width: 402, columns: 3, yearCounts: [2, 5, 1])

	private func isClose(_ a: CGFloat, _ b: CGFloat) -> Bool {
		abs(a - b) < 0.001
	}

	private func center(of position: GridLayout.Position, in layout: GridLayout) -> CGPoint {
		let column = position.index % layout.columns
		return CGPoint(x: CGFloat(column) * (layout.cellSide + GridLayout.spacing) + layout.cellSide / 2, y: layout.top(of: position) + layout.cellSide / 2)
	}

	@Test func cellsFillTheWidthWithOnePointGaps() {
		#expect(isClose(layout.cellSide * 3 + 2, 402))
	}

	@Test(arguments: [320.0, 402.0, 874.0, 1366.0])
	func thumbnailWidthGivesItsColumnCount(width: Double) {
		for columns in GridLayout.columnRange {
			#expect(GridLayout.columns(width: width, thumbnailWidth: GridLayout.thumbnailWidth(columns: columns, width: width)) == columns)
		}
	}

	@Test func sectionsStackWithHeaderAndRows() {
		// Year 0: header, 1 row. Year 1: header, 2 rows.
		#expect(isClose(layout.sectionHeight(ofYear: 0), 40 + 2 + layout.cellSide))
		#expect(isClose(layout.sectionHeight(ofYear: 1), 40 + 2 + 2 * layout.cellSide + 1))
		#expect(isClose(layout.sectionTop(ofYear: 2), layout.sectionHeight(ofYear: 0) + layout.sectionHeight(ofYear: 1)))
	}

	@Test(arguments: [1, 2, 3, 4, 7, 10])
	func everyPhotoIsFoundAtItsOwnCenter(columns: Int) {
		let layout = GridLayout(width: 402, columns: columns, yearCounts: [2, 5, 1, 12])
		for year in layout.yearCounts.indices {
			for index in 0..<layout.yearCounts[year] {
				let position = GridLayout.Position(year: year, index: index)
				#expect(layout.position(at: center(of: position, in: layout)) == position)
			}
		}
	}

	@Test func aHeaderMeansTheFirstRowBelowIt() {
		let point = CGPoint(x: 10, y: layout.sectionTop(ofYear: 1) + 10)
		#expect(layout.position(at: point) == GridLayout.Position(year: 1, index: 0))
	}

	@Test func emptySpaceMeansTheNearestPhoto() {
		// Year 0 has 2 photos, so the third column of its row is empty.
		let point = CGPoint(x: 390, y: layout.top(of: GridLayout.Position(year: 0, index: 0)) + 5)
		#expect(layout.position(at: point) == GridLayout.Position(year: 0, index: 1))
		// Above the grid and past its end.
		#expect(layout.position(at: CGPoint(x: 0, y: -100)) == GridLayout.Position(year: 0, index: 0))
		#expect(layout.position(at: CGPoint(x: 0, y: 10_000)) == GridLayout.Position(year: 2, index: 0))
	}

	@Test func noYearsMeansNoPhoto() {
		#expect(GridLayout(width: 402, columns: 3, yearCounts: []).position(at: .zero) == nil)
	}

	@Test func rangesRunInGridOrderEitherWay() {
		let start = GridLayout.Position(year: 0, index: 1)
		let end = GridLayout.Position(year: 1, index: 1)
		let expected = [GridLayout.Position(year: 0, index: 1), GridLayout.Position(year: 1, index: 0), GridLayout.Position(year: 1, index: 1)]
		#expect(layout.positions(from: start, to: end) == expected)
		#expect(layout.positions(from: end, to: start) == expected)
		#expect(layout.positions(from: start, to: start) == [start])
	}
}
