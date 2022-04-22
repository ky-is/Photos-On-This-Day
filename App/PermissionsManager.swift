import Foundation
import Photos

final class PermissionsManager: ObservableObject {
	static let shared = PermissionsManager()

	@Published var permission = PHPhotoLibrary.authorizationStatus(for: .readWrite)
}
