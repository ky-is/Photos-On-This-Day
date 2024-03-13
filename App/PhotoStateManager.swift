import Photos
import Observation

@Observable final class PhotoStateManager {
	static let shared = PhotoStateManager()

	var favorites: [PHAsset: Bool] = [:]
}
