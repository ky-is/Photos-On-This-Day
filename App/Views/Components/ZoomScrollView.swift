import SwiftUI
import UIKit

struct ZoomScrollView<Content: View>: UIViewRepresentable {
	private let content: Content
	private let onZoom: (CGFloat) -> Void

	init(onZoom: @escaping (CGFloat) -> Void = { _ in }, @ViewBuilder content: () -> Content) {
		self.onZoom = onZoom
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

		let hostedView = context.coordinator.hostingController.view!
		hostedView.translatesAutoresizingMaskIntoConstraints = true
		hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		hostedView.backgroundColor = .clear

		scrollView.addSubview(hostedView)
		return scrollView
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(hostingController: UIHostingController(rootView: content), onZoom: onZoom)
	}

	func updateUIView(_ uiView: UIScrollView, context: Context) {
		context.coordinator.hostingController.rootView = content
		context.coordinator.onZoom = onZoom
	}

	final class Coordinator: NSObject, UIScrollViewDelegate {
		let hostingController: UIHostingController<Content>
		var onZoom: (CGFloat) -> Void

		init(hostingController: UIHostingController<Content>, onZoom: @escaping (CGFloat) -> Void) {
			self.hostingController = hostingController
			self.onZoom = onZoom
		}

		func viewForZooming(in scrollView: UIScrollView) -> UIView? {
			hostingController.view
		}

		func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
			onZoom(scale)
		}
	}
}
