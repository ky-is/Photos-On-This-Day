import AVFoundation
import AppIntents
import SwiftUI
import WidgetKit
import os

@main
struct PhotosOnThisDayApp: App {
	@Environment(\.scenePhase) private var scenePhase

	init() {
		UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .accent
		UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont.rounded(style: .largeTitle, bold: true)]
		UINavigationBar.appearance().titleTextAttributes = [.font: UIFont.rounded(style: .headline, bold: false)]
		do {
			try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
		} catch {
			logger.error("Audio session: \(error.localizedDescription)")
		}
	}

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
				.task {
					// Siri phrases name a year, so it needs the list of years.
					PhotosOnThisDayShortcuts.updateAppShortcutParameters()
					let state = StateManager.shared
					await state.requestPermission()
					if state.canShowPhotos {
						WidgetCenter.shared.reloadAllTimelines()
					}
				}
		}
			.onChange(of: scenePhase) { _, newPhase in
				if newPhase == .active {
					StateManager.shared.refresh()
					Task {
						await YearlyNotification.reschedule()
					}
				}
			}
	}
}

extension UIFont {
	static func rounded(style: TextStyle, bold: Bool) -> UIFont {
		let font = UIFont.preferredFont(forTextStyle: style)
		var descriptor = font.fontDescriptor.withDesign(.rounded)!
		if bold {
			descriptor = descriptor.withSymbolicTraits(.traitBold)!
		}
		return UIFont(descriptor: descriptor, size: font.pointSize)
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
