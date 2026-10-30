import Foundation

nonisolated extension UserDefaults {
	// UserDefaults is thread-safe.
	nonisolated(unsafe) static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	enum Key {
		static let filterPhotos = "filterPhotos"
		static let filterShowScreenshots = "filterShowScreenshots"
		static let filterShowShared = "filterShowShared"
		static let filterHiddenAlbums = "filterHiddenAlbums"
		static let dismissedAddWidget = "dismissedAddWidget"
		static let widgetShuffledPhotoID = "widgetShuffledPhotoID"
		// Named for the once-a-year reminder this replaced, so its saved dates carry over.
		static let reminderDate = "yearlyNotificationDate"
		static let lastReminderDate = "lastYearlyNotificationDate"
	}

	/// Photo IDs hidden by the user, keyed by `Date.dateID`.
	var filterPhotos: [String: [String]] {
		get { dictionary(forKey: Key.filterPhotos) as? [String: [String]] ?? [:] }
		set { set(newValue, forKey: Key.filterPhotos) }
	}

	var filterShowScreenshots: Bool {
		get { bool(forKey: Key.filterShowScreenshots) }
		set { set(newValue, forKey: Key.filterShowScreenshots) }
	}

	var filterShowShared: Bool {
		get { bool(forKey: Key.filterShowShared) }
		set { set(newValue, forKey: Key.filterShowShared) }
	}

	/// Albums whose photos never show, by `PHAssetCollection.localIdentifier`.
	var filterHiddenAlbums: [String] {
		get { stringArray(forKey: Key.filterHiddenAlbums) ?? [] }
		set { set(newValue, forKey: Key.filterHiddenAlbums) }
	}

	var dismissedAddWidget: Bool {
		get { bool(forKey: Key.dismissedAddWidget) }
		set { set(newValue, forKey: Key.dismissedAddWidget) }
	}

	/// The photo the widget showed when its shuffle button was tapped, so the next timeline starts with a different one.
	var widgetShuffledPhotoID: String? {
		get { string(forKey: Key.widgetShuffledPhotoID) }
		set { set(newValue, forKey: Key.widgetShuffledPhotoID) }
	}

	/// When the pending reminder is set to go out.
	var reminderDate: Date? {
		get { object(forKey: Key.reminderDate) as? Date }
		set { set(newValue, forKey: Key.reminderDate) }
	}

	/// When the last reminder went out, so the next waits a few months.
	var lastReminderDate: Date? {
		get { object(forKey: Key.lastReminderDate) as? Date }
		set { set(newValue, forKey: Key.lastReminderDate) }
	}
}
