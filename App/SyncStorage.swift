import Foundation
import WidgetKit

final class SyncStorage: ObservableObject {
	static let shared = SyncStorage()

	private let localDefaults = UserDefaults.shared

	@Published var filterPhotos: [String: [String]] {
		willSet(newValue) {
			localDefaults.set(filterPhotos, forKey: UserDefaults.Key.filterPhotos)
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}
	@Published var filterShowScreenshots: Bool {
		willSet(newValue) {
			localDefaults.set(newValue, forKey: UserDefaults.Key.filterShowScreenshots)
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}
	@Published var filterShowShared: Bool {
		willSet(newValue) {
			localDefaults.set(newValue, forKey: UserDefaults.Key.filterShowShared)
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}

	private var observers: [NSKeyValueObservation] = []

	private init() {
		filterPhotos = localDefaults.filterPhotos
		filterShowScreenshots = localDefaults.filterShowScreenshots
		filterShowShared = localDefaults.filterShowShared

		NotificationCenter.default.addObserver(self, selector: #selector(didChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

		observers.append(localDefaults.observe(\.filterPhotos) { _, _ in
			if self.filterPhotos != self.localDefaults.filterPhotos {
				DispatchQueue.main.async {
					self.filterPhotos = self.localDefaults.filterPhotos
					NSUbiquitousKeyValueStore.default.set(self.filterPhotos, forKey: UserDefaults.Key.filterPhotos)
	#if DEBUG
					NSUbiquitousKeyValueStore.default.synchronize()
	#endif
				}
			}
		})
		observers.append(localDefaults.observe(\.filterShowScreenshots) { _, _ in
			if self.filterShowScreenshots != self.localDefaults.filterShowScreenshots {
				DispatchQueue.main.async {
					self.filterShowScreenshots = self.localDefaults.filterShowScreenshots
					NSUbiquitousKeyValueStore.default.set(self.filterShowScreenshots, forKey: UserDefaults.Key.filterShowScreenshots)
	#if DEBUG
					NSUbiquitousKeyValueStore.default.synchronize()
	#endif
				}
			}
		})
		observers.append(localDefaults.observe(\.filterShowShared) { _, _ in
			if self.filterShowShared != self.localDefaults.filterShowShared {
				DispatchQueue.main.async {
					self.filterShowShared = self.localDefaults.filterShowShared
					NSUbiquitousKeyValueStore.default.set(self.filterShowShared, forKey: UserDefaults.Key.filterShowShared)
	#if DEBUG
					NSUbiquitousKeyValueStore.default.synchronize()
	#endif
				}
			}
		})
	}

	@objc private func didChangeExternally(notification: Notification) {
		let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
		DispatchQueue.main.async {
			for key in keys {
				switch key {
				case UserDefaults.Key.filterPhotos:
					self.localDefaults.set(NSUbiquitousKeyValueStore.default.dictionary(forKey: key), forKey: key)
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
