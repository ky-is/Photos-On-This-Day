import SwiftUI
import UIKit

struct UIViewButton<Label: View>: View {
	let label: Label
	let action: (UIViewBacking) -> Void

	private let backing = UIViewBacking()

	init(action: @escaping (UIViewBacking) -> Void, @ViewBuilder label: @escaping () -> Label) {
		self.action = action
		self.label = label()
	}

	var body: some View {
		Button {
			action(backing)
		} label: {
			label
				.background(backing)
		}
	}
}

struct UIViewBacking: UIViewRepresentable {
	var uiView: UIView

	init() {
		uiView = UIView()
	}

	func makeUIView(context: Context) -> UIView {
		uiView
	}
	func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ShareImageButton: View {
	let image: UIImage

	var body: some View {
		UIViewButton { backing in
			if let vc = UIApplication.shared.frontViewController {
				let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
				activityController.popoverPresentationController?.sourceView = backing.uiView
				vc.present(activityController, animated: true, completion: nil)
			}
		} label: {
			Label("Share", systemImage: "square.and.arrow.up")
				.modifier(ToolbarButtonModifier())
		}
	}
}
