import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
import IOKit.pwr_mgt
import MapKit
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

	/// A sideways two-finger swipe on a Mac trackpad, in this view's window, once per swipe: 1 when the fingers move
	/// left, like dragging the page away to the next one, -1 when they move right. Swipes over a map pan it instead.
	/// iPhone and iPad have no trackpad swipe to catch; a drag does it there.
	func onTrackpadSwipe(isEnabled: Bool, perform action: @escaping (Int) -> Void) -> some View {
		#if os(macOS)
		modifier(TrackpadSwipe(isEnabled: isEnabled, action: action))
		#else
		self
		#endif
	}
}

#if os(macOS)
private struct TrackpadSwipe: ViewModifier {
	let isEnabled: Bool
	let action: (Int) -> Void

	@State private var tracker = TrackpadSwipeTracker()

	func body(content: Content) -> some View {
		content
			.background(WindowReader(tracker: tracker))
			.onChange(of: isEnabled, initial: true) {
				tracker.isEnabled = isEnabled
			}
			.onAppear {
				tracker.action = action
				tracker.start()
			}
			.onDisappear {
				tracker.stop()
			}
	}
}

/// Adds up a swipe's sideways scrolling until it's far enough, and mostly sideways, to count.
@MainActor private final class TrackpadSwipeTracker {
	weak var window: NSWindow?
	var isEnabled = false
	var action: (Int) -> Void = { _ in }

	private var monitor: Any?
	private var distance = CGSize.zero
	/// One step per swipe, and none for a swipe that started over a map.
	private var isDone = false

	func start() {
		guard monitor == nil else { return }
		monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
			self?.handle(event)
			return event
		}
	}

	func stop() {
		if let monitor {
			NSEvent.removeMonitor(monitor)
		}
		monitor = nil
	}

	private func handle(_ event: NSEvent) {
		// Fingers on a trackpad only, not a mouse wheel or the glide after the fingers lift.
		guard isEnabled, event.window === window, event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return }
		if event.phase.contains(.began) {
			distance = .zero
			isDone = isOverMap(event)
		}
		guard event.phase.contains(.began) || event.phase.contains(.changed), !isDone else { return }
		// With natural scrolling, the deltas already follow the fingers.
		let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
		distance.width += sign * event.scrollingDeltaX
		distance.height += sign * event.scrollingDeltaY
		if abs(distance.width) > 80, abs(distance.width) > 2 * abs(distance.height) {
			isDone = true
			action(distance.width < 0 ? 1 : -1)
		}
	}

	private func isOverMap(_ event: NSEvent) -> Bool {
		var view = event.window?.contentView?.hitTest(event.locationInWindow)
		while let current = view {
			if current is MKMapView {
				return true
			}
			view = current.superview
		}
		return false
	}
}

/// Tells the tracker which window the view is in, so swipes in other windows are left alone.
private struct WindowReader: NSViewRepresentable {
	let tracker: TrackpadSwipeTracker

	func makeNSView(context: Context) -> WindowView {
		let view = WindowView()
		view.onWindowChange = { [weak tracker] window in
			tracker?.window = window
		}
		return view
	}

	func updateNSView(_ view: WindowView, context: Context) {}

	final class WindowView: NSView {
		var onWindowChange: (NSWindow?) -> Void = { _ in }

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			onWindowChange(window)
		}
	}
}
#endif

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
