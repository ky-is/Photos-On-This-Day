import Photos
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
	private static func getImageURL(cacheURL: URL, asset: PHAsset, size: CGSize, resultHandler: @escaping (URL) -> Void) {
		PHImageManager.default().requestImage(for: asset, size: size, isSynchronous: true, cropped: true) { image, _ in
			if let url = saveImageToCache(cacheURL: cacheURL, asset: asset, image: image) {
				resultHandler(url)
			}
		}
	}

	func placeholder(in context: Context) -> PhotosOnThisDayEntry {
		return PhotosOnThisDayEntry(timelineDate: Calendar.current.date(byAdding: .year, value: -1, to: Date.current())!, photoDate: nil, score: 0, imageURL: nil, configuration: ConfigurationIntent())
	}

	fileprivate static func getSnapshotEntry(for configuration: ConfigurationIntent, size: CGSize) -> PhotosOnThisDayEntry {
		let currentDate = Date.current()
		let photosFetch = getBestPhotos(fromDate: currentDate, yearDiffs: [1], idealCount: 1, onlyFavorites: false)
		var entry: PhotosOnThisDayEntry?
		if let (score, asset) = photosFetch.first {
			let cacheURL = clearCacheDirectory(for: currentDate)
			getImageURL(cacheURL: cacheURL, asset: asset, size: size) { url in
				entry = PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: asset.creationDate, score: score, imageURL: url, configuration: configuration)
			}
		}
		return entry ?? PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: nil, score: -1, imageURL: nil, configuration: configuration)
	}

	func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (PhotosOnThisDayEntry) -> ()) {
		completion(Self.getSnapshotEntry(for: configuration, size: context.displaySize))
	}

	private static let cacheContainerURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("widget")

	private static func clearCacheDirectory(for date: Date) -> URL {
		let datePath = DateFormatter.monthDay.string(from: date)
		let cacheURL = cacheContainerURL.appendingPathComponent(datePath)
		let fileManager = FileManager.default
		do {
			try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
			let children = try fileManager.contentsOfDirectory(atPath: cacheContainerURL.path)
			for child in children {
				if child != datePath {
					try fileManager.removeItem(at: cacheContainerURL.appendingPathComponent(child))
				}
			}
		} catch {
			print(#function, error)
		}
		return cacheURL
	}

	private static func saveImageToCache(cacheURL: URL, asset: PHAsset, image: UIImage?) -> URL? {
		let id = String(asset.localIdentifier.split(separator: "/")[0])
		let imageURL = cacheURL.appendingPathComponent(id)
		if let data = image?.jpegData(compressionQuality: 0.8) {
			do {
				try data.write(to: imageURL)
				return imageURL
			} catch {
				print(error)
			}
		}
		return nil
	}

	func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
		let currentDate = Date.current()
		let cacheURL = Self.clearCacheDirectory(for: currentDate)

		let nextDayStart = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!)
		let timeForUpdates = nextDayStart.timeIntervalSince(currentDate)
		let photosFetch: [ScoreAsset]
		do {
			let intervalPerUpdate: TimeInterval = 30 * .minute
			let maxEntries = Int((timeForUpdates / intervalPerUpdate).rounded(.up))
			let customYearDiffs = configuration.onlyShowYears?.compactMap { $0.yearsAgo as? Int } ?? []
			let yearDiffs = !customYearDiffs.isEmpty ? customYearDiffs : (1...MaxYearsBack).map { $0 }
			photosFetch = Array(getBestPhotos(fromDate: currentDate, yearDiffs: yearDiffs, idealCount: maxEntries, onlyFavorites: configuration.onlyShowFavorites == 1)
				.shuffled()
				.prefix(maxEntries))
		}
		let timePerUpdate = timeForUpdates / Double(photosFetch.count)
		var entries: [PhotosOnThisDayEntry] = []
		for (offset, scoreAsset) in photosFetch.enumerated() {
			autoreleasepool {
				let entryDate = currentDate.addingTimeInterval(timePerUpdate * Double(offset))
				Self.getImageURL(cacheURL: cacheURL, asset: scoreAsset.asset, size: context.displaySize) { url in
					let entry = PhotosOnThisDayEntry(timelineDate: entryDate, photoDate: scoreAsset.asset.creationDate, score: scoreAsset.score, imageURL: url, configuration: configuration)
					entries.append(entry)
				}
			}
		}
		if entries.isEmpty {
			entries.append(PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: nil, score: -1, imageURL: nil, configuration: configuration))
		}
		let timeline = Timeline(entries: entries, policy: .after(nextDayStart))
		completion(timeline)
	}
}

struct PhotosOnThisDayEntry: TimelineEntry {
	let date: Date
	let photoDate: Date?
	let imageURL: URL?
	var relevance: TimelineEntryRelevance?
	let configuration: ConfigurationIntent

	init(timelineDate: Date, photoDate: Date?, score: Float, imageURL: URL?, configuration: ConfigurationIntent) {
		self.date = timelineDate
		self.photoDate = photoDate
		self.imageURL = imageURL
		self.relevance = .init(score: score)
		self.configuration = configuration
	}
}

@main
struct PhotosOnThisDayWidget: Widget {
	var body: some WidgetConfiguration {
		IntentConfiguration(kind: WidgetKind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
			PhotosOnThisDayWidgetEntryView(entry: entry)
		}
			.configurationDisplayName("Photos On This Day")
			.description("See photos on this day from years past.")
			.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
	}
}

// View

struct PhotoWidgetView: View {
	var entry: Provider.Entry
	var size: CGSize

	var body: some View {
		ZStack {
			if let imageURL = entry.imageURL, let image = UIImage(contentsOfFile: imageURL.path) {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: size.width, height: size.height)
			} else {
				if entry.photoDate == nil {
					Color.black
					Image(systemName: "photo")
						.font(.system(size: max(size.width * 1.05, size.height * 1.36)))
						.foregroundColor(.init(white: 0.07))
						.frame(width: size.width, height: size.height)
						.unredacted()
				}
			}
		}
	}
}

struct PhotosOnThisDayWidgetEntryView: View {
	var entry: Provider.Entry

	@Environment(\.widgetFamily) private var widgetFamily

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				PhotoWidgetView(entry: entry, size: geometry.size)
					.overlay(alignment: .bottomTrailing) {
						VStack(alignment: .trailing) {
							if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
								Group {
									let isSmall = widgetFamily == .systemSmall
									let isLarge = !isSmall && widgetFamily != .systemMedium
									if !isSmall || entry.photoDate == nil {
										Group {
											if isLarge, let photoDate = entry.photoDate {
												Text(photoDate, style: .date)
											} else {
												Text(entry.photoDate ?? entry.date, formatter: DateFormatter.monthDay)
											}
										}
											.font(.system(isLarge ? .title : .title2, design: .rounded).weight(.semibold))
									}
									if let photoDate = entry.photoDate {
										Text(photoDate, format: .relative(presentation: .numeric, unitsStyle: .wide))
											.font(.system(.callout, design: .rounded).weight(.semibold))
									}
								}
									.foregroundColor(.white)
									.shadow(color: .black, radius: 1.5, x: 0, y: 1)
							} else {
								VStack(alignment: .trailing, spacing: 4) {
									Image(systemName: "photo")
										.font(.system(size: 24))
										.foregroundColor(.secondary)
									Text("Access restricted")
										.font(.system(.headline, design: .rounded))
									Text("Tap to configure!")
										.font(.system(.body, design: .rounded))
								}
									.foregroundColor(.primary)
									.multilineTextAlignment(.trailing)
							}
						}
							.padding()
							.padding(.bottom, -2)
					}
			}
		}
	}
}

struct PhotosOnThisDayWidget_Previews: PreviewProvider {
	static var previews: some View {
		PhotosOnThisDayWidgetEntryView(entry: Provider.getSnapshotEntry(for: ConfigurationIntent(), size: CGSize(width: 128, height: 128))) //NOTE size
			.previewContext(WidgetPreviewContext(family: .systemSmall))
	}
}
