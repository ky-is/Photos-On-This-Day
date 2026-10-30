import Photos
import SwiftUI

extension View {
	/// App Store screenshots (bin/app-store-screenshots.zsh): in Debug builds, `-screenshotViewer` opens the full-screen
	/// viewer on the day's first portrait photo (or first photo) once the grid has loaded. Does nothing otherwise.
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
