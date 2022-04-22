import Photos
import WidgetKit

final class StateManager: ObservableObject {
	static let shared = StateManager()

	@Published var daysChange = 0

	@Published var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if permission == .authorized || permission == .limited {
				WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
			}
		}
	}
}
