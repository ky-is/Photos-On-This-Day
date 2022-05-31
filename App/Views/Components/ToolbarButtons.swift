import SwiftUI

struct ToolbarButtonView: View {
	let title: String
	let imageName: String?
	let action: () -> Void

	init(_ title: String, imageName: String? = nil, action: @escaping () -> Void) {
		self.title = title
		self.imageName = imageName
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			Group {
				if let imageName = imageName {
					Image(systemName: imageName)
						.accessibilityLabel(title)
				} else {
					Text(title)
				}
			}
				.modifier(ToolbarButtonContentModifier())
		}
	}
}

struct ToolbarButtonContentModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.frame(minWidth: 24, minHeight: 40)
	}
}

struct ToolbarButtons_Previews: PreviewProvider {
	static var previews: some View {
		ToolbarButtonView("Info", imageName: "i.circle", action: {})
	}
}
