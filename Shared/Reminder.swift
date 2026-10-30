import Foundation
import Photos
import UserNotifications
import os

/// A photo from a past year, reduced to what choosing an occasion needs.
nonisolated struct OccasionPhoto: Sendable {
	let created: Date
	let isFavorite: Bool
}

/// A milestone anniversary worth a notification, e.g. 10 years since a day with many photos.
nonisolated struct Occasion: Equatable, Sendable {
	/// The start of the anniversary day.
	let day: Date
	let yearsAgo: Int
	let photoCount: Int
}

nonisolated enum OccasionPicker {
	/// Only round anniversaries count as special.
	static let milestones = Array(stride(from: 5, through: maxYearsBack, by: 5))
	/// A day needs at least this score to be worth a notification; a favorite counts as 3 photos.
	static let minimumScore = 3

	/// Where a window of `days` from `startDay` ends; no `days` means a year, which isn't always 365 days.
	private static func end(from startDay: Date, days: Int?, calendar: Calendar) -> Date {
		days.map { calendar.date(byAdding: .day, value: $0, to: startDay)! } ?? calendar.date(byAdding: .year, value: 1, to: startDay)!
	}

	/// Date ranges whose photos can have an anniversary, `yearsAgo` back, in the `days` from `start` (a year when not given).
	static func searchRanges(from start: Date, days: Int? = nil, yearsAgo: [Int] = milestones, calendar: Calendar = .current) -> [Range<Date>] {
		let startDay = calendar.startOfDay(for: start)
		let end = end(from: startDay, days: days, calendar: calendar)
		return yearsAgo.map { calendar.date(byAdding: .year, value: -$0, to: startDay)!..<calendar.date(byAdding: .year, value: -$0, to: end)! }
	}

	/// The best anniversary, `yearsAgo` back, in the `days` from `start` (a year when not given): the day whose photos from that many years before score highest.
	/// Ties go to the bigger anniversary, then the earlier day.
	static func best(photos: [OccasionPhoto], from start: Date, days: Int? = nil, yearsAgo: [Int] = milestones, calendar: Calendar = .current) -> Occasion? {
		let startDay = calendar.startOfDay(for: start)
		let end = end(from: startDay, days: days, calendar: calendar)
		struct Key: Hashable {
			let day: Date
			let yearsAgo: Int
		}
		var scores: [Key: (score: Int, count: Int)] = [:]
		for photo in photos {
			let photoDay = calendar.startOfDay(for: photo.created)
			for yearsAgo in yearsAgo {
				guard let anniversary = calendar.date(byAdding: .year, value: yearsAgo, to: photoDay), anniversary >= startDay, anniversary < end else { continue }
				let key = Key(day: anniversary, yearsAgo: yearsAgo)
				let current = scores[key] ?? (0, 0)
				scores[key] = (current.score + (photo.isFavorite ? 3 : 1), current.count + 1)
			}
		}
		let best = scores
			.filter { $0.value.score >= minimumScore }
			.max { ($0.value.score, $0.key.yearsAgo, -$0.key.day.timeIntervalSinceReferenceDate) < ($1.value.score, $1.key.yearsAgo, -$1.key.day.timeIntervalSinceReferenceDate) }
		return best.map { Occasion(day: $0.key.day, yearsAgo: $0.key.yearsAgo, photoCount: $0.value.count) }
	}
}

/// Every few months, reminds people who haven't seen their photos lately, on an anniversary of a day with many photos.
/// Opening the app or a widget refreshing replaces the pending reminder with one at least `quietDays` away,
/// so it only goes out after that long with neither. WidgetKit refreshes widgets that are on a screen, so a widget
/// someone keeps on their Home Screen counts as seeing their photos.
nonisolated enum Reminder {
	/// Kept from the once-a-year version, so its pending notification is replaced.
	static let identifier = "yearly-occasion"
	/// How long without opening the app or a widget refreshing before a reminder goes out, and the least time between reminders.
	static let quietDays = 90
	/// How far past the quiet time to look for a good day.
	static let windowDays = 60
	static let hour = 10

	private static let logger = Logger(subsystem: "is.ky.Photos-On-This-Day", category: "Reminder")

	/// `mayAskPermission`: only the app asks; a widget can't show the request.
	static func reschedule(mayAskPermission: Bool) async {
		let defaults = UserDefaults.shared
		let center = UNUserNotificationCenter.current()
		let now = Date()
		if let pending = defaults.reminderDate, pending <= now {
			defaults.lastReminderDate = pending
		}
		defaults.reminderDate = nil
		center.removePendingNotificationRequests(withIdentifiers: [identifier])

		guard [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { return }
		let calendar = Calendar.current
		var start = calendar.date(byAdding: .day, value: quietDays, to: now)!
		if let last = defaults.lastReminderDate {
			start = max(start, calendar.date(byAdding: .day, value: quietDays, to: last)!)
		}
		let filters = PhotoFilters(showScreenshots: defaults.filterShowScreenshots, showShared: defaults.filterShowShared, hiddenAlbumIDs: defaults.filterHiddenAlbums)
		let hiddenIDs = Set(defaults.filterPhotos.values.joined())
		// A round anniversary if there's one in the window, otherwise any year.
		var occasion = await findOccasion(from: start, yearsAgo: OccasionPicker.milestones, filters: filters, hiddenIDs: hiddenIDs)
		if occasion == nil {
			occasion = await findOccasion(from: start, yearsAgo: Array(1...maxYearsBack), filters: filters, hiddenIDs: hiddenIDs)
		}
		guard let occasion else {
			logger.info("Reminder: no occasion found")
			return
		}
		guard await canNotify(center, mayAsk: mayAskPermission) else { return }

		let content = UNMutableNotificationContent()
		content.title = String(AttributedString(localized: "^[\(occasion.yearsAgo) year](inflect: true) ago today").characters)
		content.body = String(AttributedString(localized: "You took ^[\(occasion.photoCount) photo](inflect: true) on this day in \(String(occasion.day.year - occasion.yearsAgo)).").characters)
		content.sound = .default
		var components = calendar.dateComponents([.year, .month, .day], from: occasion.day)
		components.hour = hour
		let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
		do {
			try await center.add(request)
			defaults.reminderDate = calendar.date(from: components)
			logger.info("Reminder: \(occasion.yearsAgo) years on \(occasion.day.formatted(date: .abbreviated, time: .omitted))")
		} catch {
			logger.error("Reminder failed: \(error.localizedDescription)")
		}
	}

	/// Asks for quiet (provisional) delivery the first time, which shows no permission prompt.
	private static func canNotify(_ center: UNUserNotificationCenter, mayAsk: Bool) async -> Bool {
		switch await center.notificationSettings().authorizationStatus {
		case .authorized, .provisional, .ephemeral:
			return true
		case .notDetermined where mayAsk:
			return (try? await center.requestAuthorization(options: [.alert, .sound, .provisional])) ?? false
		default:
			return false
		}
	}

	@concurrent private static func findOccasion(from start: Date, yearsAgo: [Int], filters: PhotoFilters, hiddenIDs: Set<String>) async -> Occasion? {
		var photos: [OccasionPhoto] = []
		PHAsset.fetchAssets(createdInAnyOf: OccasionPicker.searchRanges(from: start, days: windowDays, yearsAgo: yearsAgo), filters: filters).enumerateObjects { asset, _, _ in
			guard let created = asset.creationDate, !hiddenIDs.contains(asset.localIdentifier) else { return }
			photos.append(OccasionPhoto(created: created, isFavorite: asset.isFavorite))
		}
		return OccasionPicker.best(photos: photos, from: start, days: windowDays, yearsAgo: yearsAgo)
	}
}
