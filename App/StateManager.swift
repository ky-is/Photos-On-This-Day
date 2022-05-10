import Photos
import WidgetKit
import SwiftUI

final class StateManager: ObservableObject {
	static let shared = StateManager()

	@Published var daysChange = 0 {
		didSet {
			date = Calendar.current.date(byAdding: .init(day: daysChange), to: Date.current())!
		}
	}

	@Published var date = Date.current()

	@Published var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if permission == .authorized || permission == .limited {
				WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
			}
		}
	}
}
