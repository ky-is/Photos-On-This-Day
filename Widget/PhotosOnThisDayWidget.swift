import Photos
import SwiftUI
import WidgetKit

nonisolated struct Provider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> PhotosOnThisDayEntry {
		PhotosOnThisDayEntry(date: Calendar.current.date(byAdding: .year, value: -1, to: Date.current())!, score: 0)
	}

	func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> PhotosOnThisDayEntry {
		let currentDate = Date.current()
		if context.family.isAccessory {
			return Self.summaryEntry(for: configuration, at: currentDate)
		}
		guard let best = getBestPhotos(fromDate: currentDate, yearDiffs: configuration.yearDiffs(from: currentDate), idealCount: 1, onlyFavorites: configuration.onlyShowFavorites).first else {
			return .empty(at: currentDate)
		}
		let directory = await WidgetImageCache.shared.directory(for: currentDate)
		let url = await Self.imageURL(for: best.asset, context: context, in: directory)
		return PhotosOnThisDayEntry(date: currentDate, photo: best, imageURL: url)
	}

	func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<PhotosOnThisDayEntry> {
		let currentDate = Date.current()
		let nextDayStart = currentDate.startAndEndOfDay.end
		if context.family.isAccessory {
			return Timeline(entries: [Self.summaryEntry(for: configuration, at: currentDate)], policy: .after(nextDayStart))
		}

		let directory = await WidgetImageCache.shared.directory(for: currentDate)
		let timeForUpdates = nextDayStart.timeIntervalSince(currentDate)
		let maxEntries = Int((timeForUpdates / (30 * 60)).rounded(.up))
		let photos = getBestPhotos(fromDate: currentDate, yearDiffs: configuration.yearDiffs(from: currentDate), idealCount: maxEntries, onlyFavorites: configuration.onlyShowFavorites).shuffled()

		let timePerUpdate = timeForUpdates / Double(max(1, photos.count))
		var entries: [PhotosOnThisDayEntry] = []
		for (offset, photo) in photos.enumerated() {
			guard let url = await Self.imageURL(for: photo.asset, context: context, in: directory) else { continue }
			entries.append(PhotosOnThisDayEntry(date: currentDate.addingTimeInterval(timePerUpdate * Double(offset)), photo: photo, imageURL: url))
		}
		if entries.isEmpty {
			entries.append(.empty(at: currentDate))
		}
		return Timeline(entries: entries, policy: .after(nextDayStart))
	}

	/// Lock Screen widgets can't show photos, so they summarize the day instead.
	private static func summaryEntry(for configuration: ConfigurationAppIntent, at date: Date) -> PhotosOnThisDayEntry {
		let filters = PhotoFilters.current(for: date.dateID, onlyFavorites: configuration.onlyShowFavorites)
		let byYearsBack = PHAsset.assetsByYearsBack(configuration.yearDiffs(from: date), from: date, filters: filters)
		let count = byYearsBack.values.reduce(0) { $0 + $1.count }
		let years = byYearsBack.keys.map { date.year - $0 }.sorted()
		return PhotosOnThisDayEntry(date: date, score: count > 0 ? 1 : -1, photoCount: count, years: years)
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

nonisolated extension WidgetFamily {
	var isAccessory: Bool {
		[.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(self)
	}
}

nonisolated struct PhotosOnThisDayEntry: TimelineEntry {
	let date: Date
	let photoDate: Date?
	let assetID: String?
	let imageURL: URL?
	/// For Lock Screen widgets: how many photos there are today, and from which years.
	let photoCount: Int
	let years: [Int]
	let relevance: TimelineEntryRelevance?

	init(date: Date, photoDate: Date? = nil, assetID: String? = nil, imageURL: URL? = nil, score: Float, photoCount: Int = 0, years: [Int] = []) {
		self.date = date
		self.photoDate = photoDate
		self.assetID = assetID
		self.imageURL = imageURL
		self.photoCount = photoCount
		self.years = years
		self.relevance = TimelineEntryRelevance(score: score)
	}

	init(date: Date, photo: ScoredAsset, imageURL: URL?) {
		self.init(date: date, photoDate: photo.asset.creationDate, assetID: photo.asset.localIdentifier, imageURL: imageURL, score: photo.score)
	}

	static func empty(at date: Date) -> Self {
		PhotosOnThisDayEntry(date: date, score: -1)
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
			.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
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
		if widgetFamily.isAccessory {
			AccessoryView(entry: entry)
		} else {
			photoView
				.widgetURL(entry.assetID.map(DeepLink.photo(id:)))
		}
	}

	private var photoView: some View {
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

/// Lock Screen widgets: how many photos there are from past years today.
private struct AccessoryView: View {
	let entry: PhotosOnThisDayEntry

	@Environment(\.widgetFamily) private var widgetFamily

	private var yearsDescription: String? {
		guard let first = entry.years.first, let last = entry.years.last else { return nil }
		return first == last ? String(first) : "\(first)–\(last)"
	}

	var body: some View {
		Group {
			switch widgetFamily {
			case .accessoryInline:
				if entry.photoCount > 0 {
					Label("^[\(entry.photoCount) photo](inflect: true) on this day", systemImage: "photo.on.rectangle")
				} else {
					Label("No photos on this day", systemImage: "photo")
				}
			case .accessoryCircular:
				ZStack {
					AccessoryWidgetBackground()
					VStack(spacing: 0) {
						Image(systemName: "photo.on.rectangle")
							.font(.caption)
						Text(entry.photoCount, format: .number)
							.font(.title3.bold())
							.minimumScaleFactor(0.5)
					}
				}
			default:
				VStack(alignment: .leading) {
					Text("On This Day")
						.font(.headline)
						.widgetAccentable()
					if entry.photoCount > 0 {
						Text("^[\(entry.photoCount) photo](inflect: true)")
						if let yearsDescription {
							Text(yearsDescription)
								.foregroundStyle(.secondary)
						}
					} else {
						Text("No photos from past years")
							.foregroundStyle(.secondary)
					}
				}
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
			.fontDesign(.rounded)
			.containerBackground(.clear, for: .widget)
	}
}

#Preview(as: .systemMedium) {
	PhotosOnThisDayWidget()
} timeline: {
	PhotosOnThisDayEntry.empty(at: Date.current())
}

#Preview(as: .accessoryRectangular) {
	PhotosOnThisDayWidget()
} timeline: {
	PhotosOnThisDayEntry(date: Date.current(), score: 1, photoCount: 12, years: [2012, 2018])
}
