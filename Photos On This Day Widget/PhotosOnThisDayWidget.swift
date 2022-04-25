import Photos
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
	private static func getImageURL(cacheURL: URL, asset: PHAsset, size: CGSize, resultHandler: @escaping (URL) -> Void) {
		PHImageManager.default().requestImage(for: asset, size: size, isSynchronous: true, highQuality: true) { image, _ in
			autoreleasepool {
				if let url = saveImageToCache(cacheURL: cacheURL, asset: asset, image: image) {
					resultHandler(url)
				}
			}
		}
	}

	func placeholder(in context: Context) -> PhotosOnThisDayEntry {
		return PhotosOnThisDayEntry(timelineDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!, photoDate: nil, score: 0, imageURL: nil, configuration: ConfigurationIntent())
	}

	fileprivate static func getSnapshotEntry(for configuration: ConfigurationIntent, size: CGSize) -> PhotosOnThisDayEntry {
		let currentDate = Date()
		let photosFetch = PhotosFetch.getBestPhotos(fromDate: currentDate, yearDiffs: [1], maxCount: 1, onlyFavorites: false)
		var entry: PhotosOnThisDayEntry?
		if let (score, asset) = photosFetch.first {
			let cacheURL = clearCacheDirectory(for: currentDate)
			getImageURL(cacheURL: cacheURL, asset: asset, size: size) { url in
				entry = PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: asset.creationDate, score: score, imageURL: url, configuration: configuration)
			}
		}
		return entry ?? PhotosOnThisDayEntry(timelineDate: Date(), photoDate: nil, score: -1, imageURL: nil, configuration: configuration)
	}

	func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (PhotosOnThisDayEntry) -> ()) {
		completion(Self.getSnapshotEntry(for: configuration, size: context.displaySize))
	}

	private static let cacheContainerURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("widget")

	private static func clearCacheDirectory(for date: Date) -> URL {
		try? FileManager.default.removeItem(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("widget")) //TODO remove next build
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
		if let data = image?.jpegData(compressionQuality: 1) {
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
		let currentDate = Date()
		let cacheURL = Self.clearCacheDirectory(for: currentDate)

		let calendar = Calendar.current
		let nextDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
		let timeForUpdates = nextDayStart.timeIntervalSince(currentDate)
		let minutesPerUpdate: Double = context.family == .systemExtraLarge ? 60 : 30 //TODO improve memory handling
		let maxEntries = Int((timeForUpdates / (minutesPerUpdate * .minute)).rounded(.down))
		var entries: [PhotosOnThisDayEntry] = []

		let customYearDiffs = configuration.onlyShowYears?.compactMap { $0.yearsAgo as? Int } ?? []
		let yearDiffs = !customYearDiffs.isEmpty ? customYearDiffs : (1...MaxYearsBack).map { $0 }
		let photosFetch = PhotosFetch.getBestPhotos(fromDate: Date(), yearDiffs: yearDiffs, maxCount: maxEntries, onlyFavorites: configuration.onlyShowFavorites == 1).shuffled()
		let timePerUpdate = timeForUpdates / Double(photosFetch.count)
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
			.configurationDisplayName("On This Day")
			.description("See photos on this day from years past.")
			.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
	}
}

// View

struct PhotoWidgetView: View {
	var entry: Provider.Entry
	var size: CGSize

	@Environment(\.colorScheme) var colorScheme

	var body: some View {
		Group {
			if let imageURL = entry.imageURL, let image = UIImage(contentsOfFile: imageURL.path) {
				Image(uiImage: image)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: size.width, height: size.height)
			} else {
				if entry.photoDate == nil {
					Image(systemName: "photo")
						.font(.system(size: size.height * 0.75))
						.foregroundColor(colorScheme == .dark ? .init(white: 0.125) : .init(white: 0.97))
						.frame(width: size.width, height: size.height)
						.unredacted()
				} else {
					Group {
						let photosAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
						if photosAuthStatus == .authorized {
							Image(systemName: "photo")
								.font(.system(size: 64))
								.foregroundColor(.secondary)
						} else {
							Spacer()
						}
					}
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
							if entry.imageURL != nil || (entry.photoDate == nil && entry.relevance != nil && entry.relevance!.score > 0) {
								Group {
									let isSmall = widgetFamily == .systemSmall
									let isLarge = !isSmall && widgetFamily != .systemMedium
									let displayDate = entry.photoDate ?? entry.date
									if !isSmall {
										Group {
											if isLarge {
												Text(displayDate, style: .date)
											} else {
												Text(displayDate, formatter: DateFormatter.monthDay)
											}
										}
											.font(.system(isLarge ? .title : .title2, design: .rounded).weight(.semibold))
									}
									Text(displayDate, format: .relative(presentation: .numeric, unitsStyle: .wide))
										.font(.system(.callout, design: .rounded).weight(.semibold))
								}
									.foregroundColor(.white)
									.shadow(color: .black, radius: 1.5, x: 0, y: 1)
							} else {
								VStack(alignment: .trailing, spacing: 4) {
									let photosAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
									if photosAuthStatus != .authorized {
										Image(systemName: "photo")
											.font(.system(size: 24))
											.foregroundColor(.secondary)
										Text("Access restricted")
											.font(.system(.headline, design: .rounded))
									}
									if photosAuthStatus == .authorized {
										Text("No photos from this day")
											.font(.system(.headline, design: .rounded))
											.foregroundColor(.secondary)
									} else {
										Text("Tap to configure!")
											.font(.system(.body, design: .rounded))
									}
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
