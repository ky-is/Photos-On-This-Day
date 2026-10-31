import CoreGraphics

/// Where each photo sits in the day's grid, worked out the way PhotosYearView lays it out: per year a header,
/// 1pt above and below the photos, and square cells 1pt apart. Pinching, drag to select and keeping the
/// viewer's photo on screen use it instead of measuring every thumbnail.
struct GridLayout {
	/// A photo in the grid: which year, newest first, and which photo in that year.
	struct Position: Hashable, Comparable {
		let year: Int
		let index: Int

		static func < (lhs: Self, rhs: Self) -> Bool {
			(lhs.year, lhs.index) < (rhs.year, rhs.index)
		}
	}

	/// The year header's height at the default text size; it grows with larger text, see `headerHeight`.
	static let baseHeaderHeight: CGFloat = 40
	static let spacing: CGFloat = 1
	static let columnRange = 1...10

	let width: CGFloat
	let columns: Int
	/// How many photos each year has, newest year first.
	let yearCounts: [Int]
	/// Scaled with the text size by the views, so the year fits at any size.
	var headerHeight = Self.baseHeaderHeight

	/// The column count for the widest thumbnail allowed; pinching changes that width a column at a time.
	static func columns(width: CGFloat, thumbnailWidth: Double) -> Int {
		max(1, Int((width / thumbnailWidth).rounded(.up)))
	}

	/// The thumbnail width that gives `columns` columns: halfway between the widths for one more and one fewer, so rounding lands on it.
	static func thumbnailWidth(columns: Int, width: CGFloat) -> Double {
		width / (Double(columns) - 0.5)
	}

	var cellSide: CGFloat {
		(width - CGFloat(columns - 1) * Self.spacing) / CGFloat(columns)
	}

	func rows(inYear year: Int) -> Int {
		(yearCounts[year] + columns - 1) / columns
	}

	func sectionHeight(ofYear year: Int) -> CGFloat {
		headerHeight + 2 * Self.spacing + CGFloat(rows(inYear: year)) * (cellSide + Self.spacing) - Self.spacing
	}

	func sectionTop(ofYear year: Int) -> CGFloat {
		(0..<year).reduce(0) { $0 + sectionHeight(ofYear: $1) }
	}

	func top(of position: Position) -> CGFloat {
		sectionTop(ofYear: position.year) + headerHeight + Self.spacing + CGFloat(position.index / columns) * (cellSide + Self.spacing)
	}

	/// The photo at a point in the grid, or the nearest one when the point is on a header, a gap or past the end.
	func position(at point: CGPoint) -> Position? {
		var sectionTop: CGFloat = 0
		for year in yearCounts.indices where yearCounts[year] > 0 {
			let height = sectionHeight(ofYear: year)
			if point.y < sectionTop + height || year == yearCounts.indices.last {
				let photosTop = sectionTop + headerHeight + Self.spacing
				let row = min(max(0, Int((point.y - photosTop) / (cellSide + Self.spacing))), rows(inYear: year) - 1)
				let column = min(max(0, Int(point.x / (cellSide + Self.spacing))), columns - 1)
				return Position(year: year, index: min(row * columns + column, yearCounts[year] - 1))
			}
			sectionTop += height
		}
		return nil
	}

	/// Every position from one to another, either way round, in grid order.
	func positions(from start: Position, to end: Position) -> [Position] {
		let (first, last) = start < end ? (start, end) : (end, start)
		return (first.year...last.year).flatMap { year in
			let from = year == first.year ? first.index : 0
			let to = year == last.year ? last.index : yearCounts[year] - 1
			return (from...to).map { Position(year: year, index: $0) }
		}
	}
}
