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

	/// Date ranges whose photos can have an anniversary in the year from `start`.
	static func searchRanges(from start: Date, calendar: Calendar = .current) -> [Range<Date>] {
		let startDay = calendar.startOfDay(for: start)
		let end = calendar.date(byAdding: .year, value: 1, to: startDay)!
		return milestones.map { calendar.date(byAdding: .year, value: -$0, to: startDay)!..<calendar.date(byAdding: .year, value: -$0, to: end)! }
	}

	/// The best milestone anniversary in the year from `start`: the day whose photos from that many years before score highest.
	/// Ties go to the bigger milestone, then the earlier day.
	static func best(photos: [OccasionPhoto], from start: Date, calendar: Calendar = .current) -> Occasion? {
		let startDay = calendar.startOfDay(for: start)
		let end = calendar.date(byAdding: .year, value: 1, to: startDay)!
		struct Key: Hashable {
			let day: Date
			let yearsAgo: Int
		}
		var scores: [Key: (score: Int, count: Int)] = [:]
		for photo in photos {
			let photoDay = calendar.startOfDay(for: photo.created)
			for yearsAgo in milestones {
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

/// At most once a year, on a milestone anniversary, reminds people who haven't opened the app in a while.
/// Every time the app opens, the pending notification is replaced with one at least `quietDays` away, so it only goes out after that long without opening the app.
enum YearlyNotification {
	static let identifier = "yearly-occasion"
	/// How long without opening the app before the notification can go out.
	static let quietDays = 60
	static let hour = 10

	static func reschedule() async {
		let defaults = UserDefaults.shared
		let center = UNUserNotificationCenter.current()
		let now = Date()
		if let pending = defaults.yearlyNotificationDate, pending <= now {
			defaults.lastYearlyNotificationDate = pending
		}
		defaults.yearlyNotificationDate = nil
		center.removePendingNotificationRequests(withIdentifiers: [identifier])

		guard StateManager.shared.canShowPhotos else { return }
		let calendar = Calendar.current
		var start = calendar.date(byAdding: .day, value: quietDays, to: now)!
		if let last = defaults.lastYearlyNotificationDate, let nextAllowed = calendar.date(byAdding: .year, value: 1, to: last) {
			start = max(start, nextAllowed)
		}
		let filters = Filters.shared
		guard let occasion = await findOccasion(from: start, filters: PhotoFilters(showScreenshots: filters.showScreenshots, showShared: filters.showShared), hiddenIDs: Set(filters.hiddenPhotos.values.joined())) else {
			logger.info("Yearly notification: no occasion found")
			return
		}
		guard await canNotify(center) else { return }

		let content = UNMutableNotificationContent()
		content.title = String(AttributedString(localized: "^[\(occasion.yearsAgo) year](inflect: true) ago today").characters)
		content.body = String(AttributedString(localized: "You took ^[\(occasion.photoCount) photo](inflect: true) on this day in \(String(occasion.day.year - occasion.yearsAgo)).").characters)
		content.sound = .default
		var components = calendar.dateComponents([.year, .month, .day], from: occasion.day)
		components.hour = hour
		let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
		do {
			try await center.add(request)
			defaults.yearlyNotificationDate = calendar.date(from: components)
			logger.info("Yearly notification: \(occasion.yearsAgo) years on \(occasion.day.formatted(date: .abbreviated, time: .omitted))")
		} catch {
			logger.error("Yearly notification failed: \(error.localizedDescription)")
		}
	}

	/// Asks for quiet (provisional) delivery the first time, which shows no permission prompt.
	private static func canNotify(_ center: UNUserNotificationCenter) async -> Bool {
		switch await center.notificationSettings().authorizationStatus {
		case .authorized, .provisional, .ephemeral:
			return true
		case .notDetermined:
			return (try? await center.requestAuthorization(options: [.alert, .sound, .provisional])) ?? false
		default:
			return false
		}
	}

	@concurrent private static func findOccasion(from start: Date, filters: PhotoFilters, hiddenIDs: Set<String>) async -> Occasion? {
		var photos: [OccasionPhoto] = []
		PHAsset.fetchAssets(createdInAnyOf: OccasionPicker.searchRanges(from: start), filters: filters).enumerateObjects { asset, _, _ in
			guard let created = asset.creationDate, !hiddenIDs.contains(asset.localIdentifier) else { return }
			photos.append(OccasionPhoto(created: created, isFavorite: asset.isFavorite))
		}
		return OccasionPicker.best(photos: photos, from: start)
	}
}
