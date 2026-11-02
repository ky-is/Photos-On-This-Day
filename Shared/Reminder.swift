import Foundation
import Photos
import UserNotifications
import os

/// A photo from a past year, reduced to what choosing an occasion needs.
nonisolated struct OccasionPhoto: Sendable {
	let created: Date
	let isFavorite: Bool
	/// How many photos this one stands for, when only some of a big library are looked at.
	var weight = 1
}

/// A milestone anniversary worth a notification, e.g. 10 years since a day with many photos.
nonisolated struct Occasion: Equatable, Sendable {
	/// The start of the anniversary day.
	let day: Date
	let yearsAgo: Int
	var photoCount: Int
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
				scores[key] = (current.score + photo.weight * (photo.isFavorite ? 3 : 1), current.count + photo.weight)
			}
		}
		let best = scores
			.filter { $0.value.score >= minimumScore }
			.max { ($0.value.score, $0.key.yearsAgo, -$0.key.day.timeIntervalSinceReferenceDate) < ($1.value.score, $1.key.yearsAgo, -$1.key.day.timeIntervalSinceReferenceDate) }
		return best.map { Occasion(day: $0.key.day, yearsAgo: $0.key.yearsAgo, photoCount: $0.value.count) }
	}
}

/// Every few months, reminds people who haven't seen their photos lately, on an anniversary of a day with many photos.
/// Opening the app or a widget refreshing moves the pending reminder to at least `quietDays` away when it's any nearer,
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
	/// The most photos read to find the busiest day. Bigger libraries are sampled: only which day is busiest matters.
	static let sampleSize = 1500

	private static let logger = Logger(subsystem: "is.ky.Photos-On-This-Day", category: "Reminder")

	/// Daily Reminder, from the menu: a notification each morning on the days with photos from past years, instead of the
	/// occasional one.
	static let dailyKey = "dailyReminder"
	static let dailyIdentifierPrefix = "daily-"
	/// How many days ahead the daily reminders are scheduled. Opening the app or a widget refreshing tops them up.
	static let dailyDays = 14
	static let dailyHour = 9

	/// `mayAskPermission`: only the app asks; a widget can't show the request.
	static func reschedule(mayAskPermission: Bool) async {
		let defaults = UserDefaults.shared
		let center = UNUserNotificationCenter.current()
		let now = Date()
		let daily = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(dailyIdentifierPrefix) }
		if defaults.bool(forKey: dailyKey) {
			defaults.reminderDate = nil
			center.removePendingNotificationRequests(withIdentifiers: [identifier])
			// Still a week or more ahead: leave them, rather than count photos again on every open and widget refresh.
			guard daily.count < dailyDays / 2 else { return }
			center.removePendingNotificationRequests(withIdentifiers: daily)
			await scheduleDaily(from: now, center: center, mayAsk: mayAskPermission)
			return
		}
		center.removePendingNotificationRequests(withIdentifiers: daily)
		if let pending = defaults.reminderDate, pending <= now {
			defaults.lastReminderDate = pending
		}
		let calendar = Calendar.current
		let earliest = calendar.date(byAdding: .day, value: quietDays, to: now)!
		// Still far enough off: leave it, rather than search the library again on every open and widget refresh.
		if let pending = defaults.reminderDate, pending >= earliest, await center.pendingNotificationRequests().contains(where: { $0.identifier == identifier }) {
			return
		}
		defaults.reminderDate = nil
		center.removePendingNotificationRequests(withIdentifiers: [identifier])

		guard [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)) else { return }
		var start = earliest
		if let last = defaults.lastReminderDate {
			start = max(start, calendar.date(byAdding: .day, value: quietDays, to: last)!)
		}
		let filters = PhotoFilters(showScreenshots: defaults.filterShowScreenshots, showShared: defaults.filterShowShared, hiddenAlbumIDs: defaults.filterHiddenAlbums)
		let hiddenIDs = Set(defaults.filterPhotos.values.joined())
		guard let occasion = await findOccasion(from: start, filters: filters, hiddenIDs: hiddenIDs) else {
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

	/// The coming days' reminders, from today if it's still before the hour, each with that day's photos from past years.
	/// A day without any gets none.
	private static func scheduleDaily(from now: Date, center: UNUserNotificationCenter, mayAsk: Bool) async {
		guard [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)), await canNotifyDaily(center, mayAsk: mayAsk) else { return }
		let calendar = Calendar.current
		let first = calendar.component(.hour, from: now) < dailyHour ? 0 : 1
		for offset in first..<(first + dailyDays) {
			let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
			let years = await pastYearCounts(on: day)
			guard let oldest = years.keys.max() else { continue }
			let photoCount = years.values.reduce(0, +)
			let content = UNMutableNotificationContent()
			content.title = String(AttributedString(localized: "^[\(oldest) year](inflect: true) ago today").characters)
			content.body = String(AttributedString(localized: "^[\(photoCount) photo](inflect: true) from ^[\(years.count) year](inflect: true) on this day.").characters)
			content.sound = .default
			var components = calendar.dateComponents([.year, .month, .day], from: day)
			components.hour = dailyHour
			let request = UNNotificationRequest(identifier: dailyIdentifierPrefix + day.dateID, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
			do {
				try await center.add(request)
			} catch {
				logger.error("Daily reminder failed: \(error.localizedDescription)")
			}
		}
	}

	/// How many photos each past year has on `day`, by years back, with the same filters as the grid.
	@concurrent private static func pastYearCounts(on day: Date) async -> [Int: Int] {
		PHAsset.assetsByYearsBack(Array(1...maxYearsBack), from: day, filters: .current(for: day.dateID)).mapValues(\.count).filter { $0.value > 0 }
	}

	/// Daily reminders were asked for, so they ask for alerts outright rather than quiet delivery.
	private static func canNotifyDaily(_ center: UNUserNotificationCenter, mayAsk: Bool) async -> Bool {
		switch await center.notificationSettings().authorizationStatus {
		case .authorized, .ephemeral:
			return true
		case .notDetermined where mayAsk, .provisional where mayAsk:
			return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
		case .provisional:
			return true
		default:
			return false
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

	/// One look at the window in every past year, sampled in big libraries; then the chosen day's photos are counted exactly for the message.
	@concurrent private static func findOccasion(from start: Date, filters: PhotoFilters, hiddenIDs: Set<String>) async -> Occasion? {
		let anyYear = Array(1...maxYearsBack)
		let fetch = PHAsset.fetchAssets(createdInAnyOf: OccasionPicker.searchRanges(from: start, days: windowDays, yearsAgo: anyYear), filters: filters)
		let step = max(1, fetch.count / sampleSize)
		var photos: [OccasionPhoto] = []
		fetch.enumerateObjects(at: IndexSet(stride(from: 0, to: fetch.count, by: step)), options: []) { asset, _, _ in
			guard let created = asset.creationDate, !hiddenIDs.contains(asset.localIdentifier) else { return }
			photos.append(OccasionPhoto(created: created, isFavorite: asset.isFavorite, weight: step))
		}
		// A round anniversary if there's one in the window, otherwise any year.
		guard var occasion = OccasionPicker.best(photos: photos, from: start, days: windowDays) ?? OccasionPicker.best(photos: photos, from: start, days: windowDays, yearsAgo: anyYear) else { return nil }
		if step > 1 {
			// Counting a fetch doesn't load its photos, so the one day can be exact.
			let calendar = Calendar.current
			let photoDay = calendar.date(byAdding: .year, value: -occasion.yearsAgo, to: occasion.day)!
			let dayFilters = PhotoFilters(showScreenshots: filters.showScreenshots, showShared: filters.showShared, hiddenIDs: Array(hiddenIDs), hiddenAlbumIDs: filters.hiddenAlbumIDs)
			occasion.photoCount = PHAsset.fetchAssets(createdInAnyOf: [photoDay..<calendar.date(byAdding: .day, value: 1, to: photoDay)!], filters: dayFilters).count
		}
		return occasion
	}
}
