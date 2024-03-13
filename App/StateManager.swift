import Photos
import WidgetKit
import SwiftUI

@Observable final class StateManager {
	static let shared = StateManager()

	var daysChange = 0 {
		didSet {
			date = Calendar.current.date(byAdding: .init(day: daysChange), to: Date.current())!
		}
	}

	var daysScanned = 0

	var date = Date.current()

	var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if permission == .authorized || permission == .limited {
				WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
			}
		}
	}
}

let currentYear = Calendar.current.component(.year, from: Date.current())
