import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
import IOKit.pwr_mgt
#endif

// Small differences between iPhone and Mac, kept here so views read the same on both.

extension ToolbarItemPlacement {
	/// The left of the top bar, or the navigation area of a Mac window's toolbar.
	static var leadingBar: ToolbarItemPlacement {
		#if os(iOS)
		.topBarLeading
		#else
		.navigation
		#endif
	}

	/// The right of the top bar, or the main actions of a Mac window's toolbar.
	static var trailingBar: ToolbarItemPlacement {
		#if os(iOS)
		.topBarTrailing
		#else
		.primaryAction
		#endif
	}

	/// The bottom toolbar on iPhone and iPad. A Mac window has no bottom bar, so these join its toolbar.
	static var bottomActions: ToolbarItemPlacement {
		#if os(iOS)
		.bottomBar
		#else
		.primaryAction
		#endif
	}
}

extension URL {
	/// Where people allow photo access: the app's page in Settings, or Photos privacy in System Settings on a Mac.
	static var photoPrivacySettings: URL {
		#if os(iOS)
		URL(string: UIApplication.openSettingsURLString)!
		#else
		URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!
		#endif
	}
}

enum Pasteboard {
	static func copy(_ string: String) {
		#if os(iOS)
		UIPasteboard.general.string = string
		#else
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(string, forType: .string)
		#endif
	}
}

extension View {
	/// A small title in the bar. The Mac's titles are already small.
	func inlineNavigationTitle() -> some View {
		#if os(iOS)
		navigationBarTitleDisplayMode(.inline)
		#else
		self
		#endif
	}

	/// Hides the status bar and home indicator, for full screen photos. A Mac window has neither.
	func hidesSystemOverlays(_ isHidden: Bool = true) -> some View {
		#if os(iOS)
		statusBarHidden(isHidden)
			.persistentSystemOverlays(isHidden ? .hidden : .automatic)
		#else
		self
		#endif
	}

	/// Shows or hides the top and bottom bars. A Mac window keeps its toolbar.
	func barsVisibility(_ isVisible: Bool) -> some View {
		#if os(iOS)
		toolbarVisibility(isVisible ? .visible : .hidden, for: .navigationBar, .bottomBar)
		#else
		self
		#endif
	}

	/// Shows or hides the bottom bar on iPhone and iPad.
	func bottomBarVisibility(_ isVisible: Bool) -> some View {
		#if os(iOS)
		toolbarVisibility(isVisible ? .visible : .hidden, for: .bottomBar)
		#else
		self
		#endif
	}

	/// Full screen on iPhone and iPad; a sheet the size of the window on a Mac, which has no full screen cover.
	func fullScreen<Cover: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Cover) -> some View {
		#if os(iOS)
		fullScreenCover(isPresented: isPresented, content: content)
		#else
		sheet(isPresented: isPresented) {
			content()
				.frame(minWidth: 640, idealWidth: 1024, minHeight: 480, idealHeight: 720)
		}
		#endif
	}

	/// The pointer highlight on iPad.
	func pointerHighlight() -> some View {
		#if os(iOS)
		hoverEffect(.highlight)
		#else
		self
		#endif
	}

	/// Keeps the screen from dimming or sleeping while the view shows, as in a slideshow.
	func keepsScreenAwake() -> some View {
		modifier(KeepsScreenAwake())
	}
}

private struct KeepsScreenAwake: ViewModifier {
	#if os(macOS)
	@State private var assertion: IOPMAssertionID = 0
	#endif

	func body(content: Content) -> some View {
		content
			.onAppear {
				#if os(iOS)
				UIApplication.shared.isIdleTimerDisabled = true
				#else
				IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Slideshow" as CFString, &assertion)
				#endif
			}
			.onDisappear {
				#if os(iOS)
				UIApplication.shared.isIdleTimerDisabled = false
				#else
				IOPMAssertionRelease(assertion)
				#endif
			}
	}
}
