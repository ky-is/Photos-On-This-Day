import Foundation
import Photos
import WidgetKit

final class PermissionsManager: ObservableObject {
	static let shared = PermissionsManager()

	@Published var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite) {
		didSet {
			if permission == .authorized || permission == .limited {
				WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
			}
		}
	}
}
