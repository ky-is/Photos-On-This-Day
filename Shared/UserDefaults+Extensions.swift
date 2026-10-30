import Foundation

nonisolated extension UserDefaults {
	// UserDefaults is thread-safe.
	nonisolated(unsafe) static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	enum Key {
		static let filterPhotos = "filterPhotos"
		static let filterShowScreenshots = "filterShowScreenshots"
		static let filterShowShared = "filterShowShared"
		static let dismissedAddWidget = "dismissedAddWidget"
		static let widgetShuffledPhotoID = "widgetShuffledPhotoID"
		static let yearlyNotificationDate = "yearlyNotificationDate"
		static let lastYearlyNotificationDate = "lastYearlyNotificationDate"
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

	var dismissedAddWidget: Bool {
		get { bool(forKey: Key.dismissedAddWidget) }
		set { set(newValue, forKey: Key.dismissedAddWidget) }
	}

	/// The photo the widget showed when its shuffle button was tapped, so the next timeline starts with a different one.
	var widgetShuffledPhotoID: String? {
		get { string(forKey: Key.widgetShuffledPhotoID) }
		set { set(newValue, forKey: Key.widgetShuffledPhotoID) }
	}

	/// When the pending once-a-year notification is set to go out.
	var yearlyNotificationDate: Date? {
		get { object(forKey: Key.yearlyNotificationDate) as? Date }
		set { set(newValue, forKey: Key.yearlyNotificationDate) }
	}

	/// When the last once-a-year notification went out, so the next waits a year.
	var lastYearlyNotificationDate: Date? {
		get { object(forKey: Key.lastYearlyNotificationDate) as? Date }
		set { set(newValue, forKey: Key.lastYearlyNotificationDate) }
	}
}
