import SwiftUI

extension View {
	/// Secondary text that stays readable at caption and footnote sizes: the system's secondary gray is only about 3.5:1.
	/// Full strength with Increase Contrast.
	func secondaryTextStyle() -> some View {
		modifier(SecondaryTextStyle())
	}
}

/// A grouped list's section title in the readable secondary color; the system's own is too light at that size.
struct SectionTitle: View {
	let title: LocalizedStringKey

	init(_ title: LocalizedStringKey) {
		self.title = title
	}

	var body: some View {
		Text(title)
			.secondaryTextStyle()
	}
}

private struct SecondaryTextStyle: ViewModifier {
	@Environment(\.colorSchemeContrast) private var contrast

	func body(content: Content) -> some View {
		content.foregroundStyle(.primary.opacity(contrast == .increased ? 1 : 0.62))
	}
}
