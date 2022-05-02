import Photos

final class PhotoStateManager: ObservableObject {
	static let shared = PhotoStateManager()

	@Published var favorites: [PHAsset: Bool] = [:]
	@Published var emptyYearsBack: [Bool] = []
}
