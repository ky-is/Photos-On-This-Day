import SwiftUI

private struct PhotosYearHeader: View {
	let fetch: PhotosFetch

	var body: some View {
		Text((currentYear - fetch.yearsBack).description)
			.font(.system(.headline, design: .rounded))
			.padding(.horizontal)
			.frame(height: 32)
			.frame(maxWidth: .greatestFiniteMagnitude, alignment: .leading)
			.background(.regularMaterial)
	}
}

struct PhotosYearView: View {
	@ObservedObject var fetch: PhotosFetch

	@Environment(\.screenSize) private var screenSize

	var body: some View {
		if !fetch.assets.isEmpty {
			Section(header: PhotosYearHeader(fetch: fetch)) {
				let columns: [GridItem] = Array(repeating: .init(.flexible(minimum: 64, maximum: 256), spacing: 1, alignment: .leading), count: Int(ceil(screenSize.width / 187)))
				LazyVGrid(columns: columns, alignment: .leading, spacing: 1) {
					ForEach(fetch.assets, id: \.localIdentifier) { asset in
						GeometryReader { geometry in
							PhotosYearThumbnail(asset: asset, dateID: fetch.dateID, size: geometry.size)
						}
							.aspectRatio(1, contentMode: .fill)
					}
				}
					.padding(.vertical, 1)
			}
		}
	}
}

struct PhotosYearView_Previews: PreviewProvider {
	static var previews: some View {
		PhotosYearView(fetch: PhotosFetch(fromDate: Date.current(), yearsBack: 1))
			.environment(\.screenSize, UIScreen.main.bounds.size)
	}
}
