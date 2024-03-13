import Foundation
import WidgetKit

private var observers: [NSKeyValueObservation] = []

extension UserDefaults {
	static let shared = UserDefaults(suiteName: "group.is.ky.Photos-On-This-Day")!

	struct Key {
		static let filterPhotos = "filterPhotos"
		static let filterShowScreenshots = "filterShowScreenshots"
		static let filterShowShared = "filterShowShared"

		// Unsynced

		static let dismissedAddWidget = "dismissedAddWidget"
	}

	@objc dynamic var filterPhotos: [String: [String]] {
		get {
			dictionary(forKey: #function) as? [String: [String]] ?? [:]
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var filterShowScreenshots: Bool {
		get {
			bool(forKey: #function)
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	@objc dynamic var filterShowShared: Bool {
		get {
			bool(forKey: #function)
		}
		set(value) {
			set(value, forKey: #function)
		}
	}
	
	@objc dynamic var dismissedAddWidget: Bool {
		get {
			bool(forKey: #function)
		}
		set(value) {
			set(value, forKey: #function)
		}
	}

	func observe() {
		NotificationCenter.default.addObserver(self, selector: #selector(didChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)

		observed(\.filterPhotos) {
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
		observed(\.filterShowScreenshots) {
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
		observed(\.filterShowShared) {
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
	}

	func updateAddedWidget() {
		if !UserDefaults.shared.dismissedAddWidget {
			WidgetCenter.shared.getCurrentConfigurations { result in
				switch result {
				case let .success(info):
					if info.count > 0 {
						UserDefaults.shared.dismissedAddWidget = true
					}
				case let .failure(error): print(error)
				}
			}
		}
	}

	private func observed<Value>(_ keyPath: KeyPath<UserDefaults, Value>, apply: (() -> Void)? = nil) {
		observers.append(observe(keyPath) { defaults, change in
			NSUbiquitousKeyValueStore.default.set(defaults[keyPath: keyPath], forKey: NSExpression(forKeyPath: keyPath).keyPath)
#if DEBUG
			NSUbiquitousKeyValueStore.default.synchronize()
#endif
			apply?()
		})
	}

	@objc private func didChangeExternally(notification: Notification) {
		if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
			keys.forEach { set(NSUbiquitousKeyValueStore.default.object(forKey: $0), forKey: $0) }
#if DEBUG
			synchronize()
#endif
		}
	}
}
