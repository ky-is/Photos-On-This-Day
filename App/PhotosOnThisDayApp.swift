import SwiftUI
import Photos
import WidgetKit

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
			PermissionsManager.shared.permission = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
		return true
	}
}
