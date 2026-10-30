import Photos
import SwiftUI

private struct PhotosYearHeader: View {
	let year: Int

	var body: some View {
		Text(String(year))
			.font(.headline)
			.padding(.horizontal)
			.frame(height: 32)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.regularMaterial)
	}
}

struct PhotosYearView: View {
	let year: PhotoYear

	@Environment(\.screenSize) private var screenSize

	var body: some View {
		Section {
			let columns = Array(repeating: GridItem(.flexible(minimum: 64, maximum: 256), spacing: 1, alignment: .leading), count: max(1, Int((screenSize.width / 187).rounded(.up))))
			LazyVGrid(columns: columns, alignment: .leading, spacing: 1) {
				ForEach(year.assets, id: \.localIdentifier) { asset in
					GeometryReader { geometry in
						PhotosYearThumbnail(asset: asset, dateID: year.dateID, size: geometry.size)
					}
						.aspectRatio(1, contentMode: .fill)
				}
			}
				.padding(.vertical, 1)
		} header: {
			PhotosYearHeader(year: year.year)
		}
	}
}
