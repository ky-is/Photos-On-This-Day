import Foundation
import WidgetKit

final class SyncStorage: ObservableObject {
	static let shared = SyncStorage()

	let localDefaults = UserDefaults.shared

	@Published var filterShowScreenshots: Bool {
		willSet {
			localDefaults.set(newValue, forKey: UserDefaults.Key.filterShowScreenshots)
			StateManager.shared.updateDate()
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}

	}
	@Published var filterShowShared: Bool {
		willSet {
			localDefaults.set(newValue, forKey: UserDefaults.Key.filterShowShared)
			StateManager.shared.updateDate()
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}

	private var observers: [NSKeyValueObservation] = []

	private init() {
		filterShowScreenshots = localDefaults.filterShowScreenshots
		filterShowShared = localDefaults.filterShowShared

		NotificationCenter.default.addObserver(self, selector: #selector(didChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

		observers.append(localDefaults.observe(\.filterShowScreenshots) { (defaults, change) in
			DispatchQueue.main.async {
				self.filterShowScreenshots = self.localDefaults.filterShowScreenshots
				NSUbiquitousKeyValueStore.default.set(self.filterShowScreenshots, forKey: UserDefaults.Key.filterShowScreenshots)
#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
#endif
			}
		})
		observers.append(localDefaults.observe(\.filterShowShared) { (defaults, change) in
			DispatchQueue.main.async {
				self.filterShowShared = self.localDefaults.filterShowShared
				NSUbiquitousKeyValueStore.default.set(self.filterShowShared, forKey: UserDefaults.Key.filterShowShared)
#if DEBUG
				NSUbiquitousKeyValueStore.default.synchronize()
#endif
			}
		})
	}

	@objc private func didChangeExternally(notification: Notification) {
		let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
		DispatchQueue.main.async {
			for key in keys {
				switch key {
				case UserDefaults.Key.filterShowScreenshots:
					self.localDefaults.set(NSUbiquitousKeyValueStore.default.bool(forKey: key), forKey: key)
				case UserDefaults.Key.filterShowShared:
					self.localDefaults.set(NSUbiquitousKeyValueStore.default.bool(forKey: key), forKey: key)
				default:
					print("UNKNOWN EXTERNAL KEY", key)
				}
			}
#if DEBUG
			self.localDefaults.synchronize()
#endif
		}
	}
}
