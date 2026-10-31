import SwiftUI

/// One step in or out, as VoiceOver's zoom action asks. Each is new, so the same step can repeat.
struct ZoomStep: Equatable {
	let id = UUID()
	let zoomsIn: Bool
}

#if os(iOS)
import UIKit

struct ZoomScrollView<Content: View>: UIViewRepresentable {
	private let content: Content
	private let zoomStep: ZoomStep?
	/// Whether the content is zoomed in, each time that changes.
	private let onZoom: (Bool) -> Void
	private let onTap: () -> Void
	private let onPinchClose: (() -> Void)?

	/// Pinch or double-tap to zoom, like in Photos. Pinching in below full size calls `onPinchClose`. A new `zoomStep` zooms one step.
	init(zoomStep: ZoomStep? = nil, onZoom: @escaping (Bool) -> Void = { _ in }, onTap: @escaping () -> Void = {}, onPinchClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
		self.zoomStep = zoomStep
		self.onPinchClose = onPinchClose
		self.onZoom = onZoom
		self.onTap = onTap
		self.content = content()
	}

	func makeUIView(context: Context) -> UIScrollView {
		let scrollView = UIScrollView()
		scrollView.delegate = context.coordinator
		scrollView.maximumZoomScale = 8
		scrollView.minimumZoomScale = 1
		scrollView.bouncesZoom = true
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		// Panning only while zoomed in, so swipes at full size page between photos or close the viewer.
		scrollView.panGestureRecognizer.isEnabled = false

		let hostedView = context.coordinator.hostingController.view!
		hostedView.translatesAutoresizingMaskIntoConstraints = true
		hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		hostedView.backgroundColor = .clear

		scrollView.addSubview(hostedView)

		let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped))
		doubleTap.numberOfTapsRequired = 2
		scrollView.addGestureRecognizer(doubleTap)
		let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
		tap.require(toFail: doubleTap)
		doubleTap.delegate = context.coordinator
		tap.delegate = context.coordinator
		scrollView.addGestureRecognizer(tap)
		return scrollView
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(hostingController: UIHostingController(rootView: content), onZoom: onZoom, onTap: onTap, onPinchClose: onPinchClose)
	}

	func updateUIView(_ uiView: UIScrollView, context: Context) {
		context.coordinator.hostingController.rootView = content
		context.coordinator.onZoom = onZoom
		context.coordinator.onTap = onTap
		context.coordinator.onPinchClose = onPinchClose
		if zoomStep != context.coordinator.handledStep {
			context.coordinator.handledStep = zoomStep
			if let zoomStep {
				// After the update, since zooming reports back into SwiftUI state.
				Task {
					let scale = zoomStep.zoomsIn ? uiView.zoomScale * 2 : uiView.zoomScale / 2
					uiView.setZoomScale(min(max(scale, uiView.minimumZoomScale), uiView.maximumZoomScale), animated: true)
				}
			}
		}
	}

	final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
		let hostingController: UIHostingController<Content>
		var onZoom: (Bool) -> Void
		var onTap: () -> Void
		var onPinchClose: (() -> Void)?
		var handledStep: ZoomStep?
		private var isZoomedIn = false
		private var isClosing = false

		init(hostingController: UIHostingController<Content>, onZoom: @escaping (Bool) -> Void, onTap: @escaping () -> Void, onPinchClose: (() -> Void)?) {
			self.hostingController = hostingController
			self.onZoom = onZoom
			self.onTap = onTap
			self.onPinchClose = onPinchClose
		}

		/// Leaves taps on the toolbars floating over the photo to their buttons.
		func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
			touch.view?.isDescendant(of: hostingController.view) ?? false
		}

		@objc func tapped() {
			onTap()
		}

		/// Zooms in on the tapped spot, or back out when already zoomed.
		@objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
			guard let scrollView = gesture.view as? UIScrollView else { return }
			if scrollView.zoomScale > scrollView.minimumZoomScale {
				scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
			} else {
				let point = gesture.location(in: hostingController.view)
				let size = CGSize(width: scrollView.bounds.width / 3, height: scrollView.bounds.height / 3)
				scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
			}
		}

		func viewForZooming(in scrollView: UIScrollView) -> UIView? {
			hostingController.view
		}

		func scrollViewDidZoom(_ scrollView: UIScrollView) {
			// Pinching in below full size closes the photo, like in Photos.
			if scrollView.isZooming, scrollView.zoomScale < scrollView.minimumZoomScale * 0.8, let onPinchClose, !isClosing {
				isClosing = true
				onPinchClose()
				return
			}
			// Report crossing into or out of zoomed in, not every step of the pinch.
			let isZoomedIn = scrollView.zoomScale > scrollView.minimumZoomScale * 1.02
			if isZoomedIn != self.isZoomedIn {
				self.isZoomedIn = isZoomedIn
				scrollView.panGestureRecognizer.isEnabled = isZoomedIn
				onZoom(isZoomedIn)
			}
		}

		func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
			isClosing = false
		}
	}
}
#else
import AppKit

/// Pinch on the trackpad or double-click to zoom, click to show or hide the bars. The Mac's version of the iPhone one above.
struct ZoomScrollView<Content: View>: NSViewRepresentable {
	private let content: Content
	private let zoomStep: ZoomStep?
	private let onZoom: (Bool) -> Void
	private let onTap: () -> Void

	/// `onPinchClose` is for iPhone; on the Mac, the back button and Escape close the viewer.
	init(zoomStep: ZoomStep? = nil, onZoom: @escaping (Bool) -> Void = { _ in }, onTap: @escaping () -> Void = {}, onPinchClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
		self.zoomStep = zoomStep
		self.onZoom = onZoom
		self.onTap = onTap
		self.content = content()
	}

	func makeNSView(context: Context) -> NSScrollView {
		let scrollView = NSScrollView()
		scrollView.allowsMagnification = true
		scrollView.minMagnification = 1
		scrollView.maxMagnification = 8
		scrollView.drawsBackground = false
		scrollView.hasVerticalScroller = false
		scrollView.hasHorizontalScroller = false

		let hostingView = context.coordinator.hostingView
		hostingView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.documentView = hostingView
		let clipView = scrollView.contentView
		NSLayoutConstraint.activate([
			hostingView.widthAnchor.constraint(equalTo: clipView.widthAnchor),
			hostingView.heightAnchor.constraint(equalTo: clipView.heightAnchor),
		])

		NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.magnificationChanged), name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
		let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleClicked))
		doubleClick.numberOfClicksRequired = 2
		let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked))
		click.delegate = context.coordinator
		context.coordinator.doubleClick = doubleClick
		scrollView.addGestureRecognizer(doubleClick)
		scrollView.addGestureRecognizer(click)
		return scrollView
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(hostingView: NSHostingView(rootView: content), onZoom: onZoom, onTap: onTap)
	}

	func updateNSView(_ scrollView: NSScrollView, context: Context) {
		context.coordinator.hostingView.rootView = content
		context.coordinator.onZoom = onZoom
		context.coordinator.onTap = onTap
		if zoomStep != context.coordinator.handledStep {
			context.coordinator.handledStep = zoomStep
			if let zoomStep {
				// After the update, since zooming reports back into SwiftUI state.
				let coordinator = context.coordinator
				Task {
					coordinator.zoom(scrollView, in: zoomStep.zoomsIn)
				}
			}
		}
	}

	final class Coordinator: NSObject, NSGestureRecognizerDelegate {
		let hostingView: NSHostingView<Content>
		var onZoom: (Bool) -> Void
		var onTap: () -> Void
		weak var doubleClick: NSClickGestureRecognizer?
		var handledStep: ZoomStep?
		private var isZoomedIn = false

		init(hostingView: NSHostingView<Content>, onZoom: @escaping (Bool) -> Void, onTap: @escaping () -> Void) {
			self.hostingView = hostingView
			self.onZoom = onZoom
			self.onTap = onTap
		}

		/// A single click waits to be sure it isn't the first of a double-click.
		func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
			otherGestureRecognizer === doubleClick
		}

		@objc func clicked() {
			onTap()
		}

		/// Zooms in on the clicked spot, or back out when already zoomed.
		@objc func doubleClicked(_ gesture: NSClickGestureRecognizer) {
			guard let scrollView = gesture.view as? NSScrollView else { return }
			let point = gesture.location(in: hostingView)
			let magnification: CGFloat = scrollView.magnification > scrollView.minMagnification ? scrollView.minMagnification : 3
			NSAnimationContext.runAnimationGroup { _ in
				scrollView.animator().setMagnification(magnification, centeredAt: point)
			} completionHandler: {
				self.report(scrollView)
			}
		}

		/// Zooms one step in or out around the middle of what shows.
		func zoom(_ scrollView: NSScrollView, in zoomsIn: Bool) {
			let magnification = min(max(zoomsIn ? scrollView.magnification * 2 : scrollView.magnification / 2, scrollView.minMagnification), scrollView.maxMagnification)
			let bounds = scrollView.contentView.bounds
			NSAnimationContext.runAnimationGroup { _ in
				scrollView.animator().setMagnification(magnification, centeredAt: NSPoint(x: bounds.midX, y: bounds.midY))
			} completionHandler: {
				self.report(scrollView)
			}
		}

		@objc func magnificationChanged(_ notification: Notification) {
			guard let scrollView = notification.object as? NSScrollView else { return }
			report(scrollView)
		}

		private func report(_ scrollView: NSScrollView) {
			let isZoomedIn = scrollView.magnification > scrollView.minMagnification * 1.02
			if isZoomedIn != self.isZoomedIn {
				self.isZoomedIn = isZoomedIn
				onZoom(isZoomedIn)
			}
		}
	}
}
#endif
