import WidgetKit

extension UserDefaults {
	struct Key {
		static let dismissedAddWidget = "dismissedAddWidget"
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
