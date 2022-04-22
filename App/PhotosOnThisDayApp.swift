import Photos
import SwiftUI

@main
struct PhotosOnThisDayApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}

final class AppDelegate: NSObject, UIApplicationDelegate, PHPhotoLibraryAvailabilityObserver {
	func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) {
		print(#function, photoLibrary.unavailabilityReason?.localizedDescription ?? "nil")
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font : UIFont.rounded(style: .headline, bold: false)]

		PHPhotoLibrary.shared().register(self)
		Task {
			if PermissionsManager.shared.permission != .limited {
				PermissionsManager.shared.permission = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
			}
		}
		return true
	}
}
