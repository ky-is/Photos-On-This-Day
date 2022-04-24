import SwiftUI
import UIKit

struct ZoomScrollView<Content: View>: UIViewRepresentable {
	private var content: Content

	init(@ViewBuilder content: () -> Content) {
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

		scrollView.addSubview(hostedView)
		return scrollView
	}

	func makeCoordinator() -> Coordinator {
		return Coordinator(hostingController: UIHostingController(rootView: content))
	}

	func updateUIView(_ uiView: UIScrollView, context: Context) {
		context.coordinator.hostingController.rootView = content
	}

	final class Coordinator: NSObject, UIScrollViewDelegate {
		var hostingController: UIHostingController<Content>

		init(hostingController: UIHostingController<Content>) {
			self.hostingController = hostingController
		}

		func viewForZooming(in scrollView: UIScrollView) -> UIView? {
			return hostingController.view
		}
	}
}
