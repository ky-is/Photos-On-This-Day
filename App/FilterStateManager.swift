import Photos
import WidgetKit

final class FilterStateManager: ObservableObject {
	static let shared = FilterStateManager()

	@Published var showShared = UserDefaults.shared.filterShowShared {
		didSet {
			UserDefaults.shared.set(showShared, forKey: UserDefaults.Key.filterShowShared)
			StateManager.shared.updateDate()
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}

	@Published var showScreenshots = UserDefaults.shared.bool(forKey: UserDefaults.Key.filterShowScreenshots) {
		didSet {
			UserDefaults.shared.set(showScreenshots, forKey: UserDefaults.Key.filterShowScreenshots)
			StateManager.shared.updateDate()
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}
}
