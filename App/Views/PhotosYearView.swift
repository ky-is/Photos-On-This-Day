import Photos
import SwiftUI

private struct PhotosYearHeader: View {
	let year: Int
	let isOverPhotos: Bool

	static let height = GridLayout.headerHeight

	var body: some View {
		// A floating label: plain over the white background, with a small backdrop once photos scroll under it.
		Text(String(year))
			.font(.headline.monospacedDigit())
			.padding(.horizontal, 10)
			.padding(.vertical, 4)
			.background {
				Color.clear
					.glassEffect(.regular, in: .capsule)
					.opacity(isOverPhotos ? 1 : 0)
			}
			.animation(.easeOut(duration: 0.15), value: isOverPhotos)
			.padding(.horizontal, 8)
			.frame(height: Self.height)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}

struct PhotosYearView: View {
	let year: PhotoYear
	/// Every photo shown for the day, so the viewer can swipe across years.
	let dayAssets: [PHAsset]

	@Environment(\.screenSize) private var screenSize

	@AppStorage(Self.thumbnailWidthKey) private var thumbnailWidth = Self.defaultThumbnailWidth
	@State private var isScrolledUnderHeader = false

	/// The widest a thumbnail may be; pinching the grid changes it, a column at a time.
	static let thumbnailWidthKey = "gridThumbnailWidth"
	static let defaultThumbnailWidth = 187.0

	var body: some View {
		Section {
			let columns = Array(repeating: GridItem(.flexible(minimum: 32), spacing: GridLayout.spacing, alignment: .leading), count: GridLayout.columns(width: screenSize.width, thumbnailWidth: thumbnailWidth))
			LazyVGrid(columns: columns, alignment: .leading, spacing: GridLayout.spacing) {
				ForEach(year.assets, id: \.localIdentifier) { asset in
					GeometryReader { geometry in
						PhotosYearThumbnail(asset: asset, dayAssets: dayAssets, dateID: year.dateID, size: geometry.size)
					}
						.aspectRatio(1, contentMode: .fill)
				}
			}
				.padding(.vertical, GridLayout.spacing)
				// The header pins at the top of the scroll view; photos are under it once the grid's top passes its bottom.
				// Only the yes/no is kept, so this updates when it flips, not on every scrolled frame.
				.onGeometryChange(for: Bool.self) { proxy in
					proxy.frame(in: .scrollView).minY < PhotosYearHeader.height - 1
				} action: { isUnder in
					isScrolledUnderHeader = isUnder
				}
		} header: {
			PhotosYearHeader(year: year.year, isOverPhotos: isScrolledUnderHeader)
		}
	}
}
