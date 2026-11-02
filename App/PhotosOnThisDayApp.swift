import AVFoundation
import AppIntents
import SwiftUI
import WidgetKit
import os

@main
struct PhotosOnThisDayApp: App {
	@Environment(\.scenePhase) private var scenePhase

	#if os(iOS)
	@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
	#elseif DEBUG
	@NSApplicationDelegateAdaptor private var screenshotDelegate: ScreenshotAppDelegate
	#endif

	var body: some Scene {
		WindowGroup {
			GeometryReader { geometry in
				ContentView()
					.environment(\.screenSize, geometry.size)
					.fontDesign(.rounded)
					.defaultAppStorage(.shared)
					.onOpenURL { url in
						Task {
							await StateManager.shared.open(url)
						}
					}
			}
				#if os(macOS)
				// Narrow enough to sit beside another window, with room for three columns and the toolbar.
				.frame(minWidth: 480, minHeight: 560)
				#endif
				.task {
					// Nothing from an earlier launch is still being shared.
					TemporaryFiles.clearAll()
					// Siri phrases name a year, so it needs the list of years.
					PhotosOnThisDayShortcuts.updateAppShortcutParameters()
					let state = StateManager.shared
					await state.requestPermission()
					if state.canShowPhotos {
						WidgetCenter.shared.reloadAllTimelines()
					}
				}
		}
			#if os(macOS)
			// Five columns of photos at first; the window can't shrink below the content's minimum.
			.defaultSize(width: 960, height: 760)
			.windowResizability(.contentMinSize)
			#endif
			.commands {
				AppCommands()
			}
			.onChange(of: scenePhase) { _, newPhase in
				if newPhase == .active {
					StateManager.shared.refresh()
					Task {
						await Reminder.reschedule(mayAskPermission: true)
					}
				}
			}
	}
}

#if os(iOS)
/// UIKit setup that has to wait for launch to finish: done in the App's init, it stops iOS from applying the accent color.
final class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .accent
		UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font: UIFont.rounded(style: .headline, bold: false)]
		do {
			try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
		} catch {
			logger.error("Audio session: \(error.localizedDescription)")
		}
		return true
	}
}

extension UIFont {
	static func rounded(style: TextStyle, bold: Bool) -> UIFont {
		// Made at the default text size, then scaled, so it follows the user's text size like the system font.
		let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
		var descriptor = font.fontDescriptor.withDesign(.rounded)!
		if bold {
			descriptor = descriptor.withSymbolicTraits(.traitBold)!
		}
		return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: font.pointSize))
	}
}

/// Keeps swipe-to-go-back working on screens that hide the back button.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
	override open func viewDidLoad() {
		super.viewDidLoad()
		interactivePopGestureRecognizer?.delegate = self
	}

	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		viewControllers.count > 1
	}
}
#endif
