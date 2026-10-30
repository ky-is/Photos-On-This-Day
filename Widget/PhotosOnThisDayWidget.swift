import Photos
import SwiftUI
import WidgetKit

nonisolated struct Provider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> PhotosOnThisDayEntry {
		PhotosOnThisDayEntry(date: Calendar.current.date(byAdding: .year, value: -1, to: Date.current())!, photoDate: nil, score: 0, imageURL: nil)
	}

	func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> PhotosOnThisDayEntry {
		let currentDate = Date.current()
		guard let best = getBestPhotos(fromDate: currentDate, yearDiffs: configuration.yearDiffs(from: currentDate), idealCount: 1, onlyFavorites: configuration.onlyShowFavorites).first else {
			return .empty(at: currentDate)
		}
		let directory = await WidgetImageCache.shared.directory(for: currentDate)
		let url = await Self.imageURL(for: best.asset, context: context, in: directory)
		return PhotosOnThisDayEntry(date: currentDate, photoDate: best.asset.creationDate, score: best.score, imageURL: url)
	}

	func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<PhotosOnThisDayEntry> {
		let currentDate = Date.current()
		let directory = await WidgetImageCache.shared.directory(for: currentDate)
		let nextDayStart = currentDate.startAndEndOfDay.end
		let timeForUpdates = nextDayStart.timeIntervalSince(currentDate)

		let maxEntries = Int((timeForUpdates / (30 * 60)).rounded(.up))
		let photos = getBestPhotos(fromDate: currentDate, yearDiffs: configuration.yearDiffs(from: currentDate), idealCount: maxEntries, onlyFavorites: configuration.onlyShowFavorites).shuffled()

		let timePerUpdate = timeForUpdates / Double(max(1, photos.count))
		var entries: [PhotosOnThisDayEntry] = []
		for (offset, photo) in photos.enumerated() {
			guard let url = await Self.imageURL(for: photo.asset, context: context, in: directory) else { continue }
			entries.append(PhotosOnThisDayEntry(date: currentDate.addingTimeInterval(timePerUpdate * Double(offset)), photoDate: photo.asset.creationDate, score: photo.score, imageURL: url))
		}
		if entries.isEmpty {
			entries.append(.empty(at: currentDate))
		}
		return Timeline(entries: entries, policy: .after(nextDayStart))
	}

	/// Reuses today's cached image when there is one, since the widget reloads whenever filters change.
	private static func imageURL(for asset: PHAsset, context: Context, in directory: URL) async -> URL? {
		let size = context.displaySize
		let cache = WidgetImageCache.shared
		if let url = await cache.cachedURL(for: asset, size: size, in: directory) {
			return url
		}
		let scale = context.environmentVariants.displayScale?.max() ?? 2
		guard let image = await PHImageManager.default().image(for: asset, size: size, scale: scale, cropped: true) else { return nil }
		return await cache.save(image, for: asset, size: size, in: directory)
	}
}

nonisolated struct PhotosOnThisDayEntry: TimelineEntry {
	let date: Date
	let photoDate: Date?
	let imageURL: URL?
	let relevance: TimelineEntryRelevance?

	init(date: Date, photoDate: Date?, score: Float, imageURL: URL?) {
		self.date = date
		self.photoDate = photoDate
		self.imageURL = imageURL
		self.relevance = TimelineEntryRelevance(score: score)
	}

	static func empty(at date: Date) -> Self {
		PhotosOnThisDayEntry(date: date, photoDate: nil, score: -1, imageURL: nil)
	}
}

@main
struct PhotosOnThisDayWidget: Widget {
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: widgetKind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
			PhotosOnThisDayWidgetEntryView(entry: entry)
		}
			.configurationDisplayName("Photos On This Day")
			.description("See photos on this day from years past.")
			.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
			.contentMarginsDisabled()
			.containerBackgroundRemovable(false)
	}
}

// View

struct PhotoWidgetView: View {
	let entry: PhotosOnThisDayEntry
	let size: CGSize

	var body: some View {
		Group {
			if let imageURL = entry.imageURL, let image = UIImage(contentsOfFile: imageURL.path()) {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: size.width, height: size.height)
			} else if entry.photoDate == nil {
				Image(systemName: "photo")
					.font(.system(size: max(size.width * 1.05, size.height * 1.36)))
					.foregroundStyle(Color(white: 0.08))
					.frame(width: size.width, height: size.height)
					.unredacted()
			}
		}
			.containerBackground(for: .widget) {
				Color.black
			}
	}
}

struct PhotosOnThisDayWidgetEntryView: View {
	let entry: PhotosOnThisDayEntry

	@Environment(\.widgetFamily) private var widgetFamily

	var body: some View {
		GeometryReader { geometry in
			PhotoWidgetView(entry: entry, size: geometry.size)
				.overlay(alignment: .bottomTrailing) {
					VStack(alignment: .trailing) {
						let isSmall = widgetFamily == .systemSmall
						if [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)) {
							Group {
								let isLarge = !isSmall && widgetFamily != .systemMedium
								if !isSmall || entry.photoDate == nil {
									Group {
										if isLarge, let photoDate = entry.photoDate {
											Text(photoDate, style: .date)
										} else {
											Text(entry.photoDate ?? entry.date, format: .monthDay)
										}
									}
										.font(isLarge ? .title : .title2).fontWeight(.semibold)
								}
								if let photoDate = entry.photoDate {
									Text(photoDate, format: .relative(presentation: .numeric, unitsStyle: .wide))
										.font(.callout.weight(.semibold))
								}
							}
								.foregroundStyle(.white)
								.shadow(color: .black, radius: 1.5, x: 0, y: 1)
						} else {
							VStack(alignment: .trailing, spacing: 4) {
								if !isSmall {
									Image(systemName: "photo")
										.font(.system(size: 24))
										.foregroundStyle(.secondary)
								}
								Text("Access restricted")
									.font(.headline)
								Text("Tap to configure!")
									.font(.body)
							}
								.foregroundStyle(.white)
								.multilineTextAlignment(.trailing)
						}
					}
						.padding()
						.padding(.bottom, -2)
				}
		}
			.fontDesign(.rounded)
	}
}

#Preview(as: .systemMedium) {
	PhotosOnThisDayWidget()
} timeline: {
	PhotosOnThisDayEntry.empty(at: Date.current())
}
