import WidgetKit

extension UserDefaults {
	static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	struct Key {
		static let dismissedAddWidget = "dismissedAddWidget"
		static let filterShowShared = "filterShowShared"
		static let filterShowScreenshots = "filterShowScreenshots"
	}

	@objc dynamic var filterShowShared: Bool {
		object(forKey: UserDefaults.Key.filterShowShared) as? Bool ?? true
	}
	@objc dynamic var filterShowScreenshots: Bool {
		object(forKey: UserDefaults.Key.filterShowScreenshots) as? Bool ?? false
	}

	func updateAddedWidget() {
		if !UserDefaults.standard.bool(forKey: UserDefaults.Key.dismissedAddWidget) {
			WidgetCenter.shared.getCurrentConfigurations { result in
				switch result {
				case let .success(info):
					if info.count > 0 {
						UserDefaults.standard.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
					}
				case let .failure(error): print(error)
				}
			}
		}
	}
}
