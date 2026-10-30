import Foundation

nonisolated extension UserDefaults {
	// UserDefaults is thread-safe.
	nonisolated(unsafe) static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	enum Key {
		static let filterPhotos = "filterPhotos"
		static let filterShowScreenshots = "filterShowScreenshots"
		static let filterShowShared = "filterShowShared"
		static let dismissedAddWidget = "dismissedAddWidget"
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
}
