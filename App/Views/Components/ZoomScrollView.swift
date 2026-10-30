import SwiftUI
import UIKit

struct ZoomScrollView<Content: View>: UIViewRepresentable {
	private let content: Content
	/// Whether the content is zoomed in, each time that changes.
	private let onZoom: (Bool) -> Void
	private let onTap: () -> Void
	private let onPinchClose: (() -> Void)?

	/// Pinch or double-tap to zoom, like in Photos. Pinching in below full size calls `onPinchClose`.
	init(onZoom: @escaping (Bool) -> Void = { _ in }, onTap: @escaping () -> Void = {}, onPinchClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
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
	}

	final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
		let hostingController: UIHostingController<Content>
		var onZoom: (Bool) -> Void
		var onTap: () -> Void
		var onPinchClose: (() -> Void)?
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
