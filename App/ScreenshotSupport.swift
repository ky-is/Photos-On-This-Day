import Photos
import SwiftUI
import WidgetKit

extension View {
	/// App Store screenshots (bin/app-store-screenshots.zsh): in Debug builds, `-screenshotViewer` opens the full-screen
	/// viewer on the day's first portrait photo (or first photo) once the grid has loaded, and `-screenshotCollage` the share
	/// collage. Does nothing otherwise.
	func screenshotSupport() -> some View {
#if DEBUG
		modifier(ScreenshotSupport())
#else
		self
#endif
	}
}

#if DEBUG
private struct ScreenshotSupport: ViewModifier {
	func body(content: Content) -> some View {
		content
			.task {
#if targetEnvironment(simulator)
				// Widgets show the same day as the app: `-screenshotDate`'s, or their usual one once launched without it
				// The stored value: reading through UserDefaults.shared would find the launch argument too
				let stored = UserDefaults.shared.persistentDomain(forName: "group.is.ky.Photos-On-This-Day")?["screenshotDate"] as? String
				let date = UserDefaults.standard.string(forKey: "screenshotDate")
				if stored != date {
					UserDefaults.shared.set(date, forKey: "screenshotDate")
					WidgetCenter.shared.reloadAllTimelines()
				}
#endif
				// `-screenshotCollage` opens the share collage instead.
				if UserDefaults.standard.bool(forKey: "screenshotCollage") {
					try? await Task.sleep(for: .seconds(1.5))
					MenuActions.shared.showsCollage = true
					return
				}
				guard UserDefaults.standard.bool(forKey: "screenshotViewer") else { return }
				// After the grid has drawn, as if the photo were tapped
				try? await Task.sleep(for: .seconds(1.5))
				let state = StateManager.shared
				guard state.openedPhoto == nil else { return }
				let assets = await state.pastYearAssets(on: state.date)
				// A portrait one if there is one, to fill the portrait screenshot
				guard let photo = assets.first(where: { $0.pixelHeight > $0.pixelWidth }) ?? assets.first else { return }
				state.openedPhoto = PhotoSelection(assets: assets, selectedID: photo.localIdentifier)
			}
	}
}
#endif

#if DEBUG && os(macOS)
/// Mac screenshots (bin/mac-screenshots.zsh) open the app in the background, where it opens no window by itself: this opens
/// one with File > New Window, the WindowGroup's own command, still without coming to the front.
final class ScreenshotAppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		guard ScreenshotLibrary.isActive else { return }
		// Light, like the iOS screenshots, whatever the Mac's appearance
		NSApp.appearance = NSAppearance(named: .aqua)
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(500))
			if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }), let item = NSApp.mainMenu?.items.compactMap(\.submenu).flatMap(\.items).first(where: { $0.keyEquivalent == "n" && $0.keyEquivalentModifierMask == .command }), let menu = item.menu {
				menu.performActionForItem(at: menu.index(of: item))
			}
			// 1440 x 900 points, 2880 x 1800 pixels captured, an App Store size, set before the grid lays out its columns
			for window in NSApp.windows where window.canBecomeMain {
				window.setFrame(NSRect(x: 60, y: 40, width: 1440, height: 900), display: true)
			}
		}
	}
}
#endif
