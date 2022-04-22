import Photos
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
	private func getImage(asset: PHAsset, size: CGSize, callback: @escaping (UIImage?) -> Void) {
		let options = PHImageRequestOptions()
		options.isSynchronous = true
		PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, userInfo in
			callback(image)
		}
	}

	func placeholder(in context: Context) -> PhotosOnThisDayEntry {
		return PhotosOnThisDayEntry(timelineDate: Date(), photoDate: nil, score: nil, image: nil, configuration: ConfigurationIntent())
	}

	func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (PhotosOnThisDayEntry) -> ()) {
		let currentDate = Date()
		let photosFetch = PhotosManager.shared.getPhotos(from: currentDate, yearsBack: 1, maxCount: 1)
		if let (score, asset) = photosFetch.first {
			getImage(asset: asset, size: context.displaySize) { image in
				let entry = PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: asset.creationDate, score: score, image: image, configuration: configuration)
				completion(entry)
			}
		} else {
			let entry = PhotosOnThisDayEntry(timelineDate: Date(), photoDate: nil, score: nil, image: nil, configuration: configuration)
			completion(entry)
		}
	}

	func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
		let manager = PhotosManager()

		let calendar = Calendar.current
		let currentDate = Date()
		let startHour = calendar.component(.hour, from: currentDate)
		let nextDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
//		let timeForUpdates = nextDayStart.timeIntervalSince(currentDate)
//		let timePerUpdate = timeForUpdates / photoAssets.results.count
		let photosNeededCount = 24 - startHour
		var entries: [PhotosOnThisDayEntry] = []
		let photosFetch = manager.getPhotos(from: Date(), yearsBack: 16, maxCount: photosNeededCount)
		var pendingRequests = 0
		for (offset, scoreAsset) in photosFetch.enumerated() {
			let entryDate = calendar.date(byAdding: .hour, value: offset, to: currentDate)!
			pendingRequests += 1
			getImage(asset: scoreAsset.asset, size: context.displaySize) { image in
				let entry = PhotosOnThisDayEntry(timelineDate: entryDate, photoDate: scoreAsset.asset.creationDate, score: scoreAsset.score, image: image, configuration: configuration)
				entries.append(entry)
			}
		}
		if entries.isEmpty {
			entries.append(PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: nil, score: nil, image: nil, configuration: configuration))
		}
		let timeline = Timeline(entries: entries, policy: .after(nextDayStart))
		completion(timeline)
	}
}

struct PhotosOnThisDayEntry: TimelineEntry {
	let date: Date
	let photoDate: Date?
	let image: UIImage?
	var relevance: TimelineEntryRelevance?
	let configuration: ConfigurationIntent

	init(timelineDate: Date, photoDate: Date?, score: Float?, image: UIImage?, configuration: ConfigurationIntent) {
		self.date = timelineDate
		self.photoDate = photoDate
		self.image = image
		self.relevance = .init(score: score ?? 0)
		self.configuration = configuration
	}
}

@main
struct PhotosOnThisDayWidget: Widget {
	let kind: String = WidgetKind

	var body: some WidgetConfiguration {
		IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
			PhotosOnThisDayWidgetEntryView(entry: entry)
		}
			.configurationDisplayName("On This Day")
			.description("Photo frame of your library and shared photos from this day in years past.")
			.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
	}
}

// View

struct PhotosOnThisDayWidgetEntryView : View {
	var entry: Provider.Entry

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				Group {
					if let image = entry.image {
						Image(uiImage: image)
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: geometry.size.width, height: geometry.size.height)
					} else {
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
					.overlay(alignment: .bottomLeading) {
						VStack(alignment: .leading) {
							if entry.image != nil {
								Group {
									if geometry.size.width >= 256 {
										if geometry.size.height >= 256 {
											Text(entry.photoDate ?? entry.date, style: .date)
										} else {
											Text(entry.photoDate ?? entry.date, formatter: DateFormatter.monthDay)
										}
									}
									if let date = entry.photoDate {
										Text(date, format: .relative(presentation: .numeric, unitsStyle: .wide))
											.font(.system(.body, design: .rounded).weight(.semibold))
									}
								}
									.font(.system(.title2, design: .rounded).weight(.semibold))
									.foregroundColor(.white)
									.shadow(color: .black, radius: 1.5, x: 0, y: 1)
							} else {
								VStack(alignment: .leading, spacing: 4) {
									let photosAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
									if photosAuthStatus != .authorized {
										Image(systemName: "photo")
											.font(.system(size: 24))
											.foregroundColor(.secondary)
									}
									Text(photosAuthStatus == .authorized ? "No photos yet" : "Access restricted")
										.font(.system(.headline, design: .rounded))
									if photosAuthStatus != .authorized {
										Text("Tap to configure!")
											.font(.system(.body, design: .rounded))
									}
								}
									.foregroundColor(.primary)
							}
						}
							.padding()
					}
			}
		}
	}
}

struct PhotosOnThisDayWidget_Previews: PreviewProvider {
	static let photosFetch = PhotosManager.shared.getPhotos(from: Date(), yearsBack: 1, maxCount: 1).first

	static var previews: some View {
		PhotosOnThisDayWidgetEntryView(entry: PhotosOnThisDayEntry(timelineDate: Date(), photoDate: nil, score: photosFetch?.score, image: nil, configuration: ConfigurationIntent()))
			.previewContext(WidgetPreviewContext(family: .systemSmall))
	}
}
