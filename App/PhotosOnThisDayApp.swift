import Photos
import SwiftUI
import WidgetKit

@main
struct PhotosOnThisDayApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

	@Environment(\.scenePhase) private var scenePhase

	var body: some Scene {
		WindowGroup {
			GeometryReader { geometryProxy in
				ContentView()
					.environment(\.screenSize, geometryProxy.size)
			}
		}
			.onChange(of: scenePhase) { newPhase in
				DispatchQueue.main.async {
					EnvironmentManager.shared.scenePhase = newPhase
				}
				#if !targetEnvironment(simulator)
				switch newPhase {
				case .active:
					let newDay = Calendar.current.component(.day, from: Date())
					let oldDay = Calendar.current.component(.day, from: StateManager.shared.date)
					if newDay != oldDay { //TODO only when tapping the photo widget
						DispatchQueue.main.async {
							StateManager.shared.daysChange = 0
						}
					}
				default: break
				}
				#endif
			}
	}
}

final class AppDelegate: NSObject, UIApplicationDelegate, PHPhotoLibraryAvailabilityObserver {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .accentColor
		UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font: UIFont.rounded(style: .headline, bold: false)]

		do {
			let audioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(.ambient, mode: .default)
		} catch {
			print(error)
		}

		PHPhotoLibrary.shared().register(self)
		if StateManager.shared.permission != .authorized && StateManager.shared.permission != .limited {
			Task(priority: .userInitiated) {
				StateManager.shared.permission = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
			}
		}
		if StateManager.shared.permission == .authorized || StateManager.shared.permission == .limited {
			WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind)
		}
		UserDefaults.standard.updateAddedWidget()
		return true
	}

	func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) {
		print(#function, photoLibrary.unavailabilityReason?.localizedDescription ?? "nil")
	}
}
