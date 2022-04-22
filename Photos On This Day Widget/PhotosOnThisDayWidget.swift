import WidgetKit
import SwiftUI
import Intents
import Photos
import Vision

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
		if let (date, score, asset) = photosFetch.first {
			getImage(asset: asset, size: context.displaySize) { image in
				let entry = PhotosOnThisDayEntry(timelineDate: currentDate, photoDate: date, score: score, image: image, configuration: configuration)
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
				let entry = PhotosOnThisDayEntry(timelineDate: entryDate, photoDate: scoreAsset.date, score: scoreAsset.score, image: image, configuration: configuration)
				entries.append(entry)
			}
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

//	let formatter: DateFormatter = {
//		let currentLocale: Locale = Locale.current
//		let dateComponents = "MMMMd"
//		let dateFormat = DateFormatter.dateFormat(fromTemplate: dateComponents, options: 0, locale: currentLocale)
//		let formatter = DateFormatter()
//		formatter.dateFormat = dateFormat
//		return formatter
//	}()

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				Group {
					let photosAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
					if photosAuthStatus == .authorized {
						if let image = entry.image {
							Image(uiImage: image)
								.resizable()
								.aspectRatio(contentMode: .fill)
								.frame(width: geometry.size.width, height: geometry.size.height)
						} else {
							Rectangle()
								.fill(.black)
						}
					}
				}
					.overlay(alignment: .bottomLeading) {
						Group {
							if geometry.size.width < 256 {
								Text(Calendar.current.component(.year, from: entry.photoDate ?? entry.date).description)
							} else {
								Text(entry.photoDate ?? entry.date, style: .date)
							}
						}
							.font(.system(.title2, design: .rounded).weight(.semibold))
							.foregroundColor(.white)
							.shadow(color: .black, radius: 1.5, x: 0, y: 1)
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
