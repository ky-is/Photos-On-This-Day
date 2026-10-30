import Photos
import SwiftUI
import WidgetKit

/// One photo per past year, as a grid.
struct YearsWidget: Widget {
	var body: some WidgetConfiguration {
		AppIntentConfiguration(kind: yearsWidgetKind, intent: YearsConfigurationAppIntent.self, provider: YearsProvider()) { entry in
			YearsWidgetView(entry: entry)
		}
			.configurationDisplayName("Years")
			.description("One photo from each year on this day.")
			.supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
			.contentMarginsDisabled()
			.containerBackgroundRemovable(false)
	}
}

nonisolated struct YearTile: Hashable, Sendable {
	let year: Int
	let assetID: String
	let imageURL: URL?
}

nonisolated struct YearsEntry: TimelineEntry {
	let date: Date
	let tiles: [YearTile]
	let relevance: TimelineEntryRelevance?

	init(date: Date, tiles: [YearTile]) {
		self.date = date
		self.tiles = tiles
		self.relevance = TimelineEntryRelevance(score: tiles.isEmpty ? -1 : Float(tiles.count))
	}
}

/// How many tiles go in each row of the grid, for `count` years in a widget `family`.
nonisolated enum YearsLayout {
	static let spacing: CGFloat = 2

	static func maxCount(for family: WidgetFamily) -> Int {
		switch family {
		case .systemMedium: 3
		case .systemLarge: 4
		default: 8
		}
	}

	static func rows(count: Int, family: WidgetFamily) -> [Int] {
		guard count > 0 else { return [] }
		switch family {
		case .systemMedium:
			return [count]
		case .systemLarge:
			return count < 4 ? (count == 3 ? [1, 2] : Array(repeating: 1, count: count)) : [2, 2]
		default:
			return count <= 3 ? [count] : [count / 2, count - count / 2]
		}
	}

	/// The size of each tile in each row, so images can be cropped to fit.
	static func tileSizes(rows: [Int], in size: CGSize) -> [CGSize] {
		guard !rows.isEmpty else { return [] }
		let height = (size.height - spacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
		return rows.map { columns in
			CGSize(width: (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns), height: height)
		}
	}
}

nonisolated struct YearsProvider: AppIntentTimelineProvider {
	/// The most different photos a year cycles through in a day, to keep the work per timeline small.
	static let maxRounds = 8

	func placeholder(in context: Context) -> YearsEntry {
		YearsEntry(date: Date.current(), tiles: [])
	}

	func snapshot(for configuration: YearsConfigurationAppIntent, in context: Context) async -> YearsEntry {
		let date = Date.current()
		return await entries(for: configuration, in: context, at: [date]).first ?? YearsEntry(date: date, tiles: [])
	}

	func timeline(for configuration: YearsConfigurationAppIntent, in context: Context) async -> Timeline<YearsEntry> {
		// A widget on screen means its photos are being seen, so push back the reminder.
		await Reminder.reschedule(mayAskPermission: false)
		let date = Date.current()
		let nextDayStart = date.startAndEndOfDay.end
		let frequency = configuration.updateFrequency
		let times = (0..<frequency.slots(until: nextDayStart, from: date)).map { date.addingTimeInterval(frequency.interval * Double($0)) }
		let entries = await entries(for: configuration, in: context, at: times)
		return Timeline(entries: entries.isEmpty ? [YearsEntry(date: date, tiles: [])] : entries, policy: .after(nextDayStart))
	}

	/// One entry per time, each showing the next photo from every year.
	private func entries(for configuration: YearsConfigurationAppIntent, in context: Context, at times: [Date]) async -> [YearsEntry] {
		guard let date = times.first else { return [] }
		let filters = PhotoFilters.current(for: date.dateID, onlyFavorites: configuration.onlyShowFavorites)
		let byYearsBack = PHAsset.assetsByYearsBack(configuration.yearDiffs(from: date), from: date, filters: filters)
		let yearsBack = Self.spread(byYearsBack.keys.sorted(), count: YearsLayout.maxCount(for: context.family))
		let rows = YearsLayout.rows(count: yearsBack.count, family: context.family)
		let sizes = YearsLayout.tileSizes(rows: rows, in: context.displaySize)
		let tileSizes = zip(rows, sizes).flatMap { Array(repeating: $1, count: $0) }
		let orderedByYear = yearsBack.map { Array(Self.ordered(byYearsBack[$0]!).prefix(Self.maxRounds)) }
		let rounds = min(times.count, orderedByYear.map(\.count).max() ?? 1)

		let directory = await WidgetImageCache.shared.directory(for: date)
		var tilesByRound: [[YearTile]] = []
		for round in 0..<rounds {
			var tiles: [YearTile] = []
			for ((yearBack, assets), size) in zip(zip(yearsBack, orderedByYear), tileSizes) {
				let asset = assets[round % assets.count]
				let url = await Self.imageURL(for: asset, size: size, context: context, in: directory)
				tiles.append(YearTile(year: date.year - yearBack, assetID: asset.localIdentifier, imageURL: url))
			}
			tilesByRound.append(tiles)
		}
		return times.enumerated().map { YearsEntry(date: $1, tiles: tilesByRound.isEmpty ? [] : tilesByRound[$0 % tilesByRound.count]) }
	}

	/// Up to `count` items spread evenly from first to last, so many years show both recent and old ones.
	static func spread(_ items: [Int], count: Int) -> [Int] {
		guard items.count > count, count > 1 else { return Array(items.prefix(count)) }
		return (0..<count).map { items[Int((Double($0) * Double(items.count - 1) / Double(count - 1)).rounded())] }
	}

	/// The year's photos in the order to show them: favorites first, then stills over videos, shuffled within each.
	private static func ordered(_ assets: [PHAsset]) -> [PHAsset] {
		assets
			.map { (score: ($0.isFavorite ? 2 : 0) + ($0.mediaType == .image ? 1 : 0), tiebreak: Int.random(in: 0..<Int.max), asset: $0) }
			.sorted { ($0.score, $0.tiebreak) > ($1.score, $1.tiebreak) }
			.map(\.asset)
	}

	private static func imageURL(for asset: PHAsset, size: CGSize, context: Context, in directory: URL) async -> URL? {
		let cache = WidgetImageCache.shared
		if let url = await cache.cachedURL(for: asset, size: size, in: directory) {
			return url
		}
		let scale = context.environmentVariants.displayScale?.max() ?? 2
		guard let image = await PHImageManager.default().image(for: asset, size: size, scale: scale, cropped: true) else { return nil }
		return await cache.save(image, for: asset, size: size, in: directory)
	}
}

struct YearsWidgetView: View {
	let entry: YearsEntry

	@Environment(\.widgetFamily) private var widgetFamily

	var body: some View {
		GeometryReader { geometry in
			let size = geometry.size
			if entry.tiles.isEmpty {
				EmptyPhotoBackground(size: size)
					.overlay(alignment: .bottomTrailing) {
						Group {
							if PHPhotoLibrary.canReadLibrary {
								VStack(alignment: .trailing) {
									Text(entry.date, format: .monthDay)
										.font(.title2.weight(.semibold))
									Text("No photos from past years")
										.font(.callout.weight(.semibold))
								}
									.foregroundStyle(.white)
							} else {
								AccessRestrictedView(showsIcon: true)
							}
						}
							.padding()
					}
			} else {
				grid(in: size)
			}
		}
			.fontDesign(.rounded)
			.containerBackground(for: .widget) {
				Color.black
			}
	}

	private func grid(in size: CGSize) -> some View {
		let rows = YearsLayout.rows(count: entry.tiles.count, family: widgetFamily)
		let sizes = YearsLayout.tileSizes(rows: rows, in: size)
		let starts = rows.indices.map { rows.prefix($0).reduce(0, +) }
		return VStack(spacing: YearsLayout.spacing) {
			ForEach(rows.indices, id: \.self) { row in
				HStack(spacing: YearsLayout.spacing) {
					ForEach(entry.tiles[starts[row]..<starts[row] + rows[row]], id: \.self) { tile in
						YearTileView(tile: tile, size: sizes[row], isLarge: rows.count == 1 && rows[0] == 1)
					}
				}
			}
		}
	}
}

private struct YearTileView: View {
	let tile: YearTile
	let size: CGSize
	let isLarge: Bool

	var body: some View {
		Link(destination: DeepLink.photo(id: tile.assetID)) {
			WidgetPhoto(imageURL: tile.imageURL, size: size)
				.frame(width: size.width, height: size.height)
				.background(Color(white: 0.08))
				.overlay(alignment: .bottomLeading) {
					Text(String(tile.year))
						.font(isLarge ? .title2.weight(.semibold) : .headline)
						.foregroundStyle(.white)
						.shadow(color: .black, radius: 1.5, x: 0, y: 1)
						.padding(.horizontal, 10)
						.padding(.vertical, 8)
				}
		}
	}
}

#Preview(as: .systemLarge) {
	YearsWidget()
} timeline: {
	YearsEntry(date: Date.current(), tiles: [])
}
