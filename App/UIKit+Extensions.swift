import UIKit

extension UIApplication {
	var windowScene: UIWindowScene? {
		let scene = connectedScenes.first { ($0 as? UIWindowScene) != nil } as? UIWindowScene
		#if DEBUG
		if scene == nil { print("No windowScene for app", connectedScenes) }
		#endif
		return scene
	}

	var frontViewController: UIViewController? {
		var viewController = windowScene?.windows.first?.rootViewController
		#if DEBUG
		if viewController == nil { print("No rootViewController for app", windowScene?.windows ?? "nil") }
		#endif
		while viewController?.presentedViewController != nil {
			viewController = viewController?.presentedViewController
		}
		return viewController
	}
}

extension UIFont {
	class func rounded(style: TextStyle, bold: Bool) -> UIFont {
		let font = UIFont.preferredFont(forTextStyle: style)
		var descriptor = font.fontDescriptor.withDesign(.rounded)!
		if bold {
			descriptor = descriptor.withSymbolicTraits(.traitBold)!
		}
		return UIFont(descriptor: descriptor, size: font.pointSize)
	}
}
