import WidgetKit

extension UserDefaults {
	static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	struct Key {
		static let dismissedAddWidget = "dismissedAddWidget"
	}

	func updateAddedWidget() {
		if !UserDefaults.shared.bool(forKey: UserDefaults.Key.dismissedAddWidget) {
			WidgetCenter.shared.getCurrentConfigurations { result in
				switch result {
				case let .success(info):
					if info.count > 0 {
						UserDefaults.shared.set(true, forKey: UserDefaults.Key.dismissedAddWidget)
					}
				case let .failure(error): print(error)
				}
			}
		}
	}
}
