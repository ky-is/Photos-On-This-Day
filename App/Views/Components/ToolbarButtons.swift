import SwiftUI

struct ToolbarButtonView: View {
	let title: LocalizedStringKey
	let imageName: String?
	let action: () -> Void

	init(_ title: LocalizedStringKey, imageName: String? = nil, action: @escaping () -> Void) {
		self.title = title
		self.imageName = imageName
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			Group {
				if let imageName {
					Image(systemName: imageName)
						.accessibilityLabel(Text(title))
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

#Preview {
	ToolbarButtonView("Info", imageName: "i.circle", action: {})
}
