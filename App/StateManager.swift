import Photos
import WidgetKit
import SwiftUI

final class StateManager: ObservableObject {
	static let shared = StateManager()

	@Published var scenePhase: ScenePhase = .active

	@Published var daysChange = 0 {
		didSet {
			updateDate()
		}
	}

	@Published var date = Date()

	func updateDate() {
		date = Calendar.current.date(byAdding: .init(day: daysChange), to: Date())!
	}

	@Published var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if permission == .authorized || permission == .limited {
				WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
			}
		}
	}
}
