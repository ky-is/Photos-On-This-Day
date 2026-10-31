import AVFoundation
import Photos
import SwiftUI
import Vision
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The best photos from each year on this day, labeled by year, to share as a post, a story, or a slideshow video.
/// The card shows right away from Photos' quick previews, then sharpens; the share image, the other format and the video follow in the background.
struct CollageView: View {
	let date: Date
	/// Newest first.
	let years: [PhotoYear]

	@State private var format: CollageFormat = {
		#if DEBUG
		// Screenshots and background checks: `-screenshotCollageFormat video` opens on the video.
		if UserDefaults.standard.string(forKey: "screenshotCollageFormat") == "video" {
			return .video
		}
		#endif
		return .post
	}()
	/// Each chosen year's photos, best first. Tapping a photo swaps it with its year's next one that isn't showing.
	@State private var ranked: [[PHAsset]]?
	/// Goes up with every swap, so cards and videos made before it get redone.
	@State private var revision = 0
	@State private var cards: [CollageFormat: RenderedCard] = [:]
	@State private var cardSize = CGSize.zero
	@State private var video: RenderedVideo?
	@State private var videoProgress = VideoProgress()
	@State private var player: AVQueuePlayer?
	@State private var looper: AVPlayerLooper?
	@State private var videoPlaying = false
	/// Full quality photos, by photo and size.
	@State private var loadedImages: [String: CGImage] = [:]
	/// Found once per photo, whatever size it's shown at.
	@State private var focuses: [String: UnitPoint] = [:]

	@Environment(\.dismiss) private var dismiss
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private struct RenderedCard {
		var card: CollageCard
		/// What gets shared: the card at 3×, once its photos are full quality.
		var image: CGImage?
		let revision: Int
	}

	private struct RenderedVideo {
		let url: URL
		let poster: CGImage
		let revision: Int
	}

	/// How far along the video is, shared with the writer as it works in the background.
	@MainActor @Observable final class VideoProgress {
		var value = 0.0
	}

	private struct Job: Hashable {
		let revision: Int
		/// In Low Power Mode the video is only made once the Video tab is picked, so picking it starts the work again.
		let waitsForVideo: Bool
	}

	private static var savesPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

	private var title: Text { Text(date, format: .dateTime.month(.wide).day()) }

	var body: some View {
		NavigationStack {
			VStack(spacing: 12) {
				preview
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				Picker("Format", selection: $format) {
					Text("Post").tag(CollageFormat.post)
					Text("Story").tag(CollageFormat.story)
					Text("Video").tag(CollageFormat.video)
				}
					.pickerStyle(.segmented)
					.labelsHidden()
					.frame(maxWidth: 320)
				Text("Tap a photo to swap it")
					.font(.footnote)
					.secondaryTextStyle()
					.opacity(format == .video ? 0 : 1)
					.accessibilityHidden(format == .video)
				// Side by side, or stacked when large text wouldn't fit them.
				let buttons = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
				buttons {
					shareButton
						.buttonStyle(.borderedProminent)
					// The image already names the app; the link is only sent if they want to.
					ShareLink(item: appStoreURL) {
						Label("Share App", systemImage: "link")
					}
						.buttonStyle(.bordered)
				}
			}
				.background {
					// ⌘1–3 pick the format from a keyboard. Hidden: the picker already shows the choice.
					Group {
						Button("Post") { format = .post }
							.keyboardShortcut("1")
						Button("Story") { format = .story }
							.keyboardShortcut("2")
						Button("Video") { format = .video }
							.keyboardShortcut("3")
					}
						.opacity(0)
						.frame(width: 0, height: 0)
						.allowsHitTesting(false)
						.accessibilityHidden(true)
				}
				.padding()
				#if os(macOS)
				// A Mac sheet takes the size its content asks for, and the scaled card asks for almost none.
				.frame(minWidth: 460, idealWidth: 540, minHeight: 680, idealHeight: 860)
				#endif
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Done") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
				.task(id: Job(revision: revision, waitsForVideo: Self.savesPower && format == .video)) {
					await prepareAll()
				}
				.onChange(of: format) { _, format in
					setVideoPlaying(format == .video && autoplaysVideo)
				}
				.onDisappear {
					setVideoPlaying(false)
				}
		}
	}

	/// Shares the card or the video once it's ready; until then it waits, greyed out, in the same place.
	@ViewBuilder private var shareButton: some View {
		let label = Label("Share", systemImage: "square.and.arrow.up")
		if format == .video, let video, video.revision == revision {
			ShareLink(item: video.url, preview: SharePreview(title, image: Image(decorative: video.poster, scale: 1))) {
				label
			}
		} else if format != .video, let card = cards[format], card.revision == revision, let cgImage = card.image {
			let image = Image(decorative: cgImage, scale: 3)
			ShareLink(item: image, preview: SharePreview(title, image: image)) {
				label
			}
		} else {
			Button {} label: {
				label
			}
				.disabled(true)
				.accessibilityHint(Text("Preparing…"))
		}
	}

	/// The preview loops on its own unless Reduce Motion is on or the system's Auto-Play Video setting is off; the button plays it either way.
	private var autoplaysVideo: Bool {
		#if os(iOS)
		!reduceMotion && UIAccessibility.isVideoAutoplayEnabled
		#else
		!reduceMotion
		#endif
	}

	private func setVideoPlaying(_ playing: Bool) {
		if playing {
			player?.play()
		} else {
			player?.pause()
		}
		videoPlaying = playing && player != nil
	}


	@ViewBuilder private var preview: some View {
		if format == .video {
			if let player, video?.revision == revision {
				PlayerLayerView(player: player)
					.accessibilityLabel(Text("Video"))
					.aspectRatio(CollageCard.width / CollageCard.storyHeight, contentMode: .fit)
					.clipShape(.rect(cornerRadius: 16))
					.overlay(alignment: .bottomTrailing) {
						Button(videoPlaying ? "Pause" : "Play", systemImage: videoPlaying ? "pause.fill" : "play.fill") {
							setVideoPlaying(!videoPlaying)
						}
							.labelStyle(.iconOnly)
							.buttonStyle(.borderedProminent)
							.buttonBorderShape(.circle)
							.padding(12)
					}
			} else {
				ProgressView(value: videoProgress.value) {
					Text("Making video…")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
					.frame(maxWidth: 220)
			}
		} else if let rendered = cards[format] {
			// The card itself, scaled to fit, so each photo can be tapped. The old one stays, dimmed, while a swap loads.
			GeometryReader { geometry in
				let scale = cardSize.width > 0 ? min(geometry.size.width / cardSize.width, geometry.size.height / cardSize.height) : 0
				rendered.card
					.onTileTap { tile in
						swapPhoto(tile, shownIn: rendered.card)
					}
					.fixedSize()
					.onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
					.clipShape(.rect(cornerRadius: 16 / max(scale, 0.01)))
					.shadow(color: .black.opacity(0.25), radius: 12 / max(scale, 0.01), y: 4 / max(scale, 0.01))
					.scaleEffect(scale)
					.frame(width: geometry.size.width, height: geometry.size.height)
			}
				.opacity(rendered.revision == revision ? 1 : 0.7)
				// The audit leaves the card's own text alone: it's the share image, drawn at a fixed size on purpose.
				.accessibilityElement(children: .contain)
				.accessibilityIdentifier("CollageCard")
		} else {
			ProgressView()
				.accessibilityLabel(Text("Loading Photos"))
		}
	}

	/// The format on screen first, then the others, so switching finds them ready.
	private func prepareAll() async {
		let chosen = CollagePrep.chosenYears(years)
		guard !chosen.isEmpty else { return }
		if ranked == nil {
			ranked = await CollagePrep.shared.ranking(for: chosen).value
		}
		guard let ranked else { return }
		let revision = revision
		for format in [format] + [CollageFormat.post, .story, .video].filter({ $0 != format }) {
			guard !Task.isCancelled else { return }
			if format == .video {
				// Making the video is the heavy part: in Low Power Mode it waits until someone picks the Video tab.
				if video?.revision != revision, format == self.format || !Self.savesPower {
					await makeVideo(chosen: chosen, ranked: ranked, revision: revision)
				}
			} else if cards[format]?.revision != revision || cards[format]?.image == nil {
				await prepareCard(format, chosen: chosen, ranked: ranked, revision: revision)
			}
		}
	}

	/// Puts the year's next photo that isn't showing in the tapped one's place, and sends the tapped one to the back of the line.
	private func swapPhoto(_ tile: CollageCard.Tile, shownIn card: CollageCard) {
		guard var photos = ranked?[tile.yearIndex] else { return }
		let showing = card.rows.joined().filter { $0.yearIndex == tile.yearIndex }.count
		guard photos.count > showing, tile.slot < showing else { return }
		let replaced = photos[tile.slot]
		let next = photos.remove(at: showing)
		photos[tile.slot] = next
		photos.append(replaced)
		ranked?[tile.yearIndex] = photos
		revision += 1
	}

	/// The card shows as soon as Photos hands over quick previews, then again with full quality photos; the share image is drawn last.
	private func prepareCard(_ format: CollageFormat, chosen: [PhotoYear], ranked: [[PHAsset]], revision: Int) async {
		let layout = CollageLayout(counts: ranked.map(\.count), format: format)
		let tileHeight = CollageCard.tileHeight(format: format, columns: layout.columns, rows: layout.rows.count)
		let requests = layout.rows.joined().map { slot in
			PhotoRequest(asset: ranked[slot.year][slot.index], size: CGSize(width: CollageCard.tileWidth(span: slot.span, columns: layout.columns), height: tileHeight))
		}
		if cards[format]?.revision != revision {
			let quick = await loadPhotos(requests, quick: true)
			guard !Task.isCancelled else { return }
			cards[format] = RenderedCard(card: makeCard(format, layout: layout, tileHeight: tileHeight, chosen: chosen, ranked: ranked, images: quick), image: nil, revision: revision)
		}
		let full = await loadPhotos(requests, quick: false)
		guard !Task.isCancelled else { return }
		let card = makeCard(format, layout: layout, tileHeight: tileHeight, chosen: chosen, ranked: ranked, images: full)
		cards[format] = RenderedCard(card: card, image: nil, revision: revision)
		// Let the sharper card draw before the share image takes the main thread.
		await Task.yield()
		guard !Task.isCancelled else { return }
		cards[format]?.image = render(card)
	}

	private struct PhotoRequest {
		let asset: PHAsset
		let size: CGSize

		var key: String { "\(asset.localIdentifier)@\(Int(size.width))x\(Int(size.height))" }
	}

	/// All at once, off the main thread. Quick ones are whatever Photos has at hand, usually instantly; full ones are kept for later.
	private func loadPhotos(_ requests: [PhotoRequest], quick: Bool) async -> [String: CGImage] {
		var images: [String: CGImage] = [:]
		var missing: [PhotoRequest] = []
		for request in requests {
			if let cached = loadedImages[request.key] {
				images[request.asset.localIdentifier] = cached
			} else {
				missing.append(request)
			}
		}
		let loaded = await withTaskGroup(of: (PhotoRequest, CGImage?).self) { group in
			for request in missing {
				group.addTask {
					(request, quick ? await TilePhotos.quick(request.asset, size: request.size) : await TilePhotos.full(request.asset, size: request.size))
				}
			}
			var loaded: [(PhotoRequest, CGImage)] = []
			for await (request, image) in group {
				if let image {
					loaded.append((request, image))
				}
			}
			return loaded
		}
		for (request, image) in loaded {
			images[request.asset.localIdentifier] = image
			if !quick {
				loadedImages[request.key] = image
			}
		}
		await findFocus(in: images)
		return images
	}

	/// Each photo's focus, worked out once from the first copy of it that loads.
	private func findFocus(in images: [String: CGImage]) async {
		let missing = images.filter { focuses[$0.key] == nil }
		guard !missing.isEmpty else { return }
		let found = await withTaskGroup(of: (String, UnitPoint).self) { group in
			for (id, image) in missing {
				group.addTask {
					(id, await PhotoFocus.point(in: image))
				}
			}
			var found: [String: UnitPoint] = [:]
			for await (id, focus) in group {
				found[id] = focus
			}
			return found
		}
		focuses.merge(found) { $1 }
	}

	private func yearRange(_ chosen: [PhotoYear]) -> String {
		chosen.count > 1 ? "\(chosen.last!.year) – \(chosen.first!.year)" : String(chosen[0].year)
	}

	private func makeCard(_ format: CollageFormat, layout: CollageLayout, tileHeight: CGFloat, chosen: [PhotoYear], ranked: [[PHAsset]], images: [String: CGImage]) -> CollageCard {
		var rows: [[CollageCard.Tile]] = []
		for row in layout.rows {
			var tiles: [CollageCard.Tile] = []
			for slot in row {
				let asset = ranked[slot.year][slot.index]
				guard let image = images[asset.localIdentifier] else { continue }
				let description = PhotosYearThumbnail.accessibilityDescription(of: asset, isFavorite: Favorites.shared.isFavorite(asset))
				tiles.append(CollageCard.Tile(id: asset.localIdentifier, year: chosen[slot.year].year, yearIndex: slot.year, slot: slot.index, span: slot.span, image: image, focus: focuses[asset.localIdentifier] ?? .center, description: description))
			}
			// A photo that failed to load leaves a gap: widen the last one to cover it.
			let filled = tiles.reduce(0) { $0 + $1.span }
			if !tiles.isEmpty, filled < layout.columns {
				tiles[tiles.count - 1].span += layout.columns - filled
			}
			if !tiles.isEmpty {
				rows.append(tiles)
			}
		}
		return CollageCard(format: format, date: date, yearCount: years.count, yearRange: yearRange(chosen), rows: rows, columns: layout.columns, tileHeight: tileHeight)
	}

	/// The story's photos one at a time, oldest year first, over the story's header.
	private func makeVideo(chosen: [PhotoYear], ranked: [[PHAsset]], revision: Int) async {
		let layout = CollageLayout(counts: ranked.map(\.count), format: .story)
		let slots = layout.rows.joined().sorted { ($0.year, -$0.index) > ($1.year, -$1.index) }
		let area = CollageCard.storyPhotoArea
		let progress = videoProgress
		progress.value = 0
		let images = await loadPhotos(slots.map { PhotoRequest(asset: ranked[$0.year][$0.index], size: area.size) }, quick: false)
		guard !Task.isCancelled else { return }
		// Loading the photos is the first tenth of the bar; writing the frames is the rest.
		progress.value = 0.1
		let slides = slots.compactMap { slot -> CollageVideo.Slide? in
			let id = ranked[slot.year][slot.index].localIdentifier
			guard let image = images[id] else { return nil }
			let year = chosen[slot.year].year
			return CollageVideo.Slide(image: image, focus: focuses[id] ?? .center, year: year, label: render(YearPill(year: year, size: 20)))
		}
		let backdrop = CollageCard(format: .story, date: date, yearCount: years.count, yearRange: yearRange(chosen), rows: [], columns: 1, tileHeight: 0)
		guard let poster = slides.first?.image, let backdropImage = render(backdrop) else { return }
		let url = TemporaryFiles.collageVideo(named: date.formatted(.dateTime.month(.wide).day()))
		let pixelArea = CGRect(x: area.minX * 3, y: area.minY * 3, width: area.width * 3, height: area.height * 3)
		do {
			try await CollageVideo.make(backdrop: backdropImage, photoArea: pixelArea, cornerRadius: 36, slides: slides, to: url) { value in
				Task { @MainActor in
					progress.value = 0.1 + 0.9 * value
				}
			}
		} catch {
			return
		}
		let player = AVQueuePlayer()
		player.isMuted = true
		looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
		self.player = player
		video = RenderedVideo(url: url, poster: poster, revision: revision)
		setVideoPlaying(format == .video && autoplaysVideo)
	}

	/// At 3×, the size everything is shared at.
	private func render(_ view: some View) -> CGImage? {
		let renderer = ImageRenderer(content: view)
		renderer.scale = 3
		return renderer.cgImage
	}
}

/// Ranks a day's photos for the collage, and keeps the latest day's ranking so opening it again is instant.
/// The first day the app shows is ranked ahead of time, since people rarely change days; others wait for the collage.
@MainActor final class CollagePrep {
	static let shared = CollagePrep()

	private var current: (key: [[String]], task: Task<[[PHAsset]], Never>)?
	private var didPrepareFirstDay = false

	/// Ranks the first day shown after launch in the background, unless in Low Power Mode. Later days are left alone.
	func prepareFirstDay(_ years: [PhotoYear]) async {
		guard !didPrepareFirstDay else { return }
		didPrepareFirstDay = true
		guard !years.isEmpty, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
		// After the grid's own thumbnails have had their turn.
		try? await Task.sleep(for: .seconds(1))
		guard !Task.isCancelled else { return }
		_ = ranking(for: Self.chosenYears(years), priority: .utility)
	}

	/// At most 9 years: the newest, the oldest, and an even spread between.
	static func chosenYears(_ years: [PhotoYear]) -> [PhotoYear] {
		let years = years.filter { !$0.assets.isEmpty }
		guard years.count > 9 else { return years }
		return (0..<9).map { years[$0 * (years.count - 1) / 8] }
	}

	/// Starts ranking these years, or hands back the ranking already under way. Only the latest day is kept.
	func ranking(for chosen: [PhotoYear], priority: TaskPriority = .userInitiated) -> Task<[[PHAsset]], Never> {
		let key = chosen.map { $0.assets.map(\.localIdentifier) }
		if let current, current.key == key {
			return current.task
		}
		current?.task.cancel()
		let task = Task(priority: priority) {
			await PhotoRanker.ranked(years: chosen)
		}
		current = (key, task)
		return task
	}
}

/// Tile photos, loaded off the main thread.
nonisolated enum TilePhotos {
	/// The first copy Photos can hand over: a cached or lower quality one if it has it.
	@concurrent static func quick(_ asset: PHAsset, size: CGSize) async -> CGImage? {
		for await (image, _) in PHImageManager.default().images(for: asset, size: size, scale: 3, cropped: false) {
			return image.cgImageForAnalysis
		}
		return nil
	}

	@concurrent static func full(_ asset: PHAsset, size: CGSize) async -> CGImage? {
		await PHImageManager.default().image(for: asset, size: size, scale: 3, cropped: false)?.cgImageForAnalysis
	}
}

/// Post is as tall as its photos need, for messages and feeds; story is 9:16, for Instagram and WhatsApp stories; video plays the story's photos one by one.
enum CollageFormat: Hashable {
	case post
	case story
	case video
}

/// Which photo goes in each cell, so every row is full.
struct CollageLayout {
	struct Slot {
		/// Index into the years.
		let year: Int
		/// Index into that year's ranked photos.
		let index: Int
		var span = 1
	}

	let columns: Int
	let rows: [[Slot]]

	/// `counts` is how many photos each year has, newest year first.
	init(counts: [Int], format: CollageFormat = .post) {
		let years = counts.count
		let total = counts.reduce(0, +)
		// A tall story keeps its tiles from getting thin by using fewer columns and more rows.
		let columns = years >= (format == .story ? 7 : 5) ? 3 : total >= 2 ? 2 : 1
		var rowCount = (years + columns - 1) / columns
		// Two years side by side make a thin strip: a 2×2 square looks better when there are photos for it.
		if columns == 2, rowCount == 1, total >= 4 {
			rowCount = 2
		}
		// A story has room for a third row of two.
		if format == .story, columns == 2, rowCount == 2, total >= 6 {
			rowCount = 3
		}
		// Years with photos to spare fill the empty cells, the one with the most spare first.
		var taken = Array(repeating: 1, count: years)
		var extra = min(rowCount * columns, total) - years
		while extra > 0, let year = taken.indices.filter({ counts[$0] > taken[$0] }).max(by: { counts[$0] - taken[$0] < counts[$1] - taken[$1] }) {
			taken[year] += 1
			extra -= 1
		}
		let slots = taken.enumerated().flatMap { year, count in (0..<count).map { Slot(year: year, index: $0) } }
		var rows = stride(from: 0, to: slots.count, by: columns).map { Array(slots[$0..<min($0 + columns, slots.count)]) }
		// Not enough photos anywhere: the last row's photos grow wider to fill it.
		if var last = rows.last, last.count < columns {
			for index in last.indices {
				last[index].span = columns / last.count + (index < columns % last.count ? 1 : 0)
			}
			rows[rows.count - 1] = last
		}
		self.columns = columns
		self.rows = rows
	}
}

/// Orders a day's photos best first: favorites, then the ones Vision scores as most memorable, skipping screenshots and near duplicates.
nonisolated enum PhotoRanker {
	/// How many photos per year get scored. Only the first few are ever used.
	private static let scoredCount = 8

	/// Every year at once.
	@concurrent static func ranked(years: [PhotoYear]) async -> [[PHAsset]] {
		await withTaskGroup(of: (Int, [PHAsset]).self) { group in
			for (index, year) in years.enumerated() {
				group.addTask {
					(index, await ranked(year.assets))
				}
			}
			var ranked = Array(repeating: [PHAsset](), count: years.count)
			for await (index, assets) in group {
				ranked[index] = assets
			}
			return ranked
		}
	}

	@concurrent static func ranked(_ assets: [PHAsset]) async -> [PHAsset] {
		let usable = assets.filter { !$0.mediaSubtypes.contains(.photoScreenshot) && !$0.mediaSubtypes.contains(.videoScreenRecording) }
		let pool = usable.isEmpty ? assets : usable
		let favorites = pool.filter(\.isFavorite)
		let others = pool.filter { !$0.isFavorite }
		// An even spread through the day, so one burst doesn't take every spot.
		let sampled = others.count > scoredCount ? (0..<scoredCount).map { others[$0 * (others.count - 1) / (scoredCount - 1)] } : others
		// All scored at once; each loads a small thumbnail.
		let scores = await withTaskGroup(of: (String, Double).self) { group in
			for asset in favorites.prefix(scoredCount) + sampled {
				group.addTask {
					(asset.localIdentifier, await score(asset))
				}
			}
			var scores: [String: Double] = [:]
			for await (id, score) in group {
				scores[id] = score
			}
			return scores
		}
		let byScore = { (assets: [PHAsset]) in assets.sorted { scores[$0.localIdentifier] ?? -10 > scores[$1.localIdentifier] ?? -10 } }
		let ordered = byScore(favorites) + byScore(others)
		// Moments apart from each other first; photos seconds from an earlier pick go to the back.
		var picked: [PHAsset] = []
		var duplicates: [PHAsset] = []
		for asset in ordered {
			let isDuplicate = picked.contains { a in
				guard let first = a.creationDate, let second = asset.creationDate else { return false }
				return abs(first.timeIntervalSince(second)) < 60
			}
			if isDuplicate {
				duplicates.append(asset)
			} else {
				picked.append(asset)
			}
		}
		return picked + duplicates
	}

	/// Vision's aesthetics score, from -1 to 1. Receipts, documents and other utility shots score far below any real photo.
	@concurrent private static func score(_ asset: PHAsset) async -> Double {
		guard !Task.isCancelled else { return 0 }
		let videoPenalty = asset.mediaType == .video ? 0.3 : 0
		guard let image = await PHImageManager.default().image(for: asset, size: CGSize(width: 300, height: 300), scale: 1, cropped: false), let cgImage = image.cgImageForAnalysis else { return -videoPenalty }
		guard let observation = try? await CalculateImageAestheticsScoresRequest().perform(on: cgImage) else { return -videoPenalty }
		return Double(observation.overallScore) - (observation.isUtility ? 2 : 0) - videoPenalty
	}
}

extension PlatformImage {
	nonisolated var cgImageForAnalysis: CGImage? {
		#if canImport(UIKit)
		cgImage
		#else
		cgImage(forProposedRect: nil, context: nil, hints: nil)
		#endif
	}
}

/// Where to center a tile's crop so it keeps what matters: the faces, or else whatever draws the eye.
nonisolated enum PhotoFocus {
	/// From 0 to 1, with the origin at the top left.
	@concurrent static func point(in cgImage: CGImage) async -> UnitPoint {
		if let faces = try? await DetectFaceRectanglesRequest().perform(on: cgImage), !faces.isEmpty {
			return center(of: faces.map(\.boundingBox.cgRect))
		}
		if let saliency = try? await GenerateAttentionBasedSaliencyImageRequest().perform(on: cgImage), !saliency.salientObjects.isEmpty {
			return center(of: saliency.salientObjects.map(\.boundingBox.cgRect))
		}
		return .center
	}

	/// Vision's rects have their origin at the bottom left.
	private static func center(of rects: [CGRect]) -> UnitPoint {
		let union = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
		return UnitPoint(x: union.midX, y: 1 - union.midY)
	}
}

/// Fills `size` with the image, cropped around `focus` instead of the middle, without showing past its edges.
private struct FocusedImage: View {
	let image: CGImage
	let focus: UnitPoint
	let size: CGSize

	var body: some View {
		let imageWidth = CGFloat(image.width)
		let imageHeight = CGFloat(image.height)
		let scale = max(size.width / imageWidth, size.height / imageHeight)
		let drawn = CGSize(width: imageWidth * scale, height: imageHeight * scale)
		let x = min(0, max(size.width - drawn.width, size.width / 2 - focus.x * drawn.width))
		let y = min(0, max(size.height - drawn.height, size.height / 2 - focus.y * drawn.height))
		Image(decorative: image, scale: 1)
			.resizable()
			.frame(width: drawn.width, height: drawn.height)
			.offset(x: x, y: y)
			.frame(width: size.width, height: size.height, alignment: .topLeading)
			.clipped()
	}
}

/// The collage itself, drawn once into an image. Quiet paper colors, with a dusk glow behind the header, so the photos stand out.
private struct CollageCard: View {
	struct Tile: Identifiable {
		let id: String
		let year: Int
		/// Index into the chosen years.
		let yearIndex: Int
		/// The year's first cell, second… Only the first is labeled.
		let slot: Int
		var span: Int
		let image: CGImage
		let focus: UnitPoint
		/// What VoiceOver reads, the same as for the photo's thumbnail in the grid.
		let description: Text
	}

	static let width: CGFloat = 360
	/// 9:16.
	static let storyHeight: CGFloat = 640
	static let padding: CGFloat = 18
	static let spacing: CGFloat = 6
	/// A story's photos sit at the bottom, under the header, with this much height.
	static let storyGridHeight: CGFloat = 484
	/// Where a story's photos are, in points; the video plays its slides here.
	static let storyPhotoArea = CGRect(x: padding, y: storyHeight - padding - storyGridHeight, width: width - padding * 2, height: storyGridHeight)

	static func tileSide(columns: Int) -> CGFloat {
		(width - padding * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
	}

	static func tileWidth(span: Int, columns: Int) -> CGFloat {
		tileSide(columns: columns) * CGFloat(span) + spacing * CGFloat(span - 1)
	}

	/// Square tiles in a post; a story's tiles stretch to fill its height.
	static func tileHeight(format: CollageFormat, columns: Int, rows: Int) -> CGFloat {
		switch format {
		case .post: tileSide(columns: columns)
		case .story, .video: (storyGridHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
		}
	}

	private static let paper = Color(red: 251 / 255, green: 249 / 255, blue: 247 / 255)
	private static let paperShade = Color(red: 246 / 255, green: 240 / 255, blue: 240 / 255)
	/// The icon's dusk sky, fading to its warm horizon, behind the header.
	private static let duskGlow = Color(red: 228 / 255, green: 206 / 255, blue: 220 / 255)
	private static let horizonGlow = Color(red: 245 / 255, green: 225 / 255, blue: 218 / 255)
	private static let ink = Color(white: 0.13)
	private static let inkSoft = Color(white: 0.4)
	private static let dusk = Color(red: 125 / 255, green: 85 / 255, blue: 105 / 255)

	let format: CollageFormat
	let date: Date
	let yearCount: Int
	let yearRange: String
	let rows: [[Tile]]
	let columns: Int
	let tileHeight: CGFloat
	private var onTap: ((Tile) -> Void)?

	init(format: CollageFormat, date: Date, yearCount: Int, yearRange: String, rows: [[Tile]], columns: Int, tileHeight: CGFloat) {
		self.format = format
		self.date = date
		self.yearCount = yearCount
		self.yearRange = yearRange
		self.rows = rows
		self.columns = columns
		self.tileHeight = tileHeight
	}

	/// The same card, with its photos tappable.
	func onTileTap(_ action: @escaping (Tile) -> Void) -> CollageCard {
		var card = self
		card.onTap = action
		return card
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
				.padding(.horizontal, Self.padding + 4)
				.padding(.top, 24)
				.padding(.bottom, 16)
			if format != .post {
				Spacer(minLength: 0)
			}
			grid
				.frame(height: format == .post ? nil : Self.storyGridHeight, alignment: .top)
				.padding(.horizontal, Self.padding)
				.padding(.bottom, Self.padding)
		}
			.frame(width: Self.width, height: format == .post ? nil : Self.storyHeight, alignment: .top)
			.background {
				ZStack(alignment: .top) {
					LinearGradient(colors: [Self.paper, Self.paperShade], startPoint: .top, endPoint: .bottom)
					LinearGradient(stops: [.init(color: Self.duskGlow, location: 0), .init(color: Self.horizonGlow, location: 0.55), .init(color: Self.horizonGlow.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
						.frame(height: 200)
				}
			}
			.environment(\.colorScheme, .light)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 2) {
			// The app's name and icon, so viewers know where it came from and can find it on the App Store.
			HStack(spacing: 7) {
				Image("ShareBadge")
					.resizable()
					.frame(width: 20, height: 20)
					.clipShape(.rect(cornerRadius: 5))
					.overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.08), lineWidth: 0.5))
					.accessibilityHidden(true)
				Text(verbatim: "Photos On This Day")
					.font(.system(size: 13, weight: .semibold, design: .rounded))
					.foregroundStyle(Self.dusk)
			}
				.padding(.bottom, 4)
			Text(date, format: .dateTime.month(.wide).day())
				.font(.system(size: 38, weight: .bold, design: .rounded))
				.foregroundStyle(Self.ink)
			HStack(spacing: 8) {
				Text("\(yearCount) years of memories")
				Text(verbatim: "·")
					.accessibilityHidden(true)
				Text(verbatim: yearRange)
			}
		}
			.font(.system(size: 15, weight: .medium, design: .rounded))
			.foregroundStyle(Self.inkSoft)
			.lineLimit(1)
			// Read as one heading: app, date, how many years.
			.accessibilityElement(children: .combine)
			.accessibilityAddTraits(.isHeader)
	}

	// Not a lazy grid: ImageRenderer draws everything at once.
	private var grid: some View {
		Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
			ForEach(rows.indices, id: \.self) { row in
				GridRow {
					ForEach(rows[row]) { tile in
						FocusedImage(image: tile.image, focus: tile.focus, size: CGSize(width: Self.tileWidth(span: tile.span, columns: columns), height: tileHeight))
							.clipShape(.rect(cornerRadius: 12))
							.overlay(alignment: .bottomLeading) {
								if tile.slot == 0 {
									YearPill(year: tile.year, size: columns == 3 ? 12 : 14)
										.padding(7)
								}
							}
							.contentShape(.rect)
							.onTapGesture {
								onTap?(tile)
							}
							.accessibilityElement()
							.accessibilityLabel(tile.description)
							.accessibilityAddTraits(.isButton)
							.accessibilityHint(Text("Swaps in another photo from the same year"))
							.accessibilityAction {
								onTap?(tile)
							}
							.gridCellColumns(tile.span)
					}
				}
			}
		}
			.shadow(color: .black.opacity(0.08), radius: 8, y: 3)
	}
}

/// The year on a photo, white on a dark capsule so it reads on any picture.
private struct YearPill: View {
	let year: Int
	let size: CGFloat

	var body: some View {
		Text(verbatim: String(year))
			.font(.system(size: size, weight: .bold, design: .rounded))
			.foregroundStyle(.white)
			.padding(.horizontal, size * 0.6)
			.padding(.vertical, size * 0.22)
			.background(.black.opacity(0.4), in: .capsule)
			.environment(\.colorScheme, .light)
	}
}

/// The video preview: muted and looping, drawn straight by AVPlayerLayer. SwiftUI's VideoPlayer crashes on the Mac.
#if canImport(UIKit)
private struct PlayerLayerView: UIViewRepresentable {
	let player: AVPlayer

	final class LayerView: UIView {
		override static var layerClass: AnyClass { AVPlayerLayer.self }
		var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
	}

	func makeUIView(context: Context) -> LayerView {
		let view = LayerView()
		view.playerLayer.videoGravity = .resizeAspect
		view.playerLayer.player = player
		return view
	}

	func updateUIView(_ view: LayerView, context: Context) {
		view.playerLayer.player = player
	}
}
#else
private struct PlayerLayerView: NSViewRepresentable {
	let player: AVPlayer

	final class LayerView: NSView {
		let playerLayer = AVPlayerLayer()

		init() {
			super.init(frame: .zero)
			playerLayer.videoGravity = .resizeAspect
			layer = playerLayer
			wantsLayer = true
		}

		required init?(coder: NSCoder) {
			nil
		}
	}

	func makeNSView(context: Context) -> LayerView {
		let view = LayerView()
		view.playerLayer.player = player
		return view
	}

	func updateNSView(_ view: LayerView, context: Context) {
		view.playerLayer.player = player
	}
}
#endif
