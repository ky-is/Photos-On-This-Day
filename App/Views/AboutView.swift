import SwiftUI

let appStoreURL = URL(string: "https://apps.apple.com/app/photos-on-this-day/id1620659723")!

struct AboutView: View {
	@Environment(\.dismiss) private var dismiss

	private var filters = Filters.shared

	var body: some View {
		NavigationStack {
			Form {
				Section {
					NavigationLink("How to add a Widget") {
						HelpAddWidgetView(inSheet: false)
					}
				} header: {
					SectionTitle("Help")
				}
				if !filters.hiddenPhotos.isEmpty {
					Section {
						NavigationLink("Hidden photos") {
							HelpHiddenPhotos()
						}
					} header: {
						SectionTitle("Manage")
					}
				}
				Section {
					Link(destination: URL(string: "\(appStoreURL.absoluteString)?action=write-review")!) {
						HStack {
							Text("Rate _Photos On This Day_")
							Image(systemName: "arrow.up.forward.square")
								.accessibilityHidden(true)
						}
					}
					ShareLink(item: appStoreURL) {
						Text("Share with a friend…")
					}
				} header: {
					SectionTitle("Share")
				}
				Section {
					Link(destination: URL(string: "https://github.com/ky-is/Photos-On-This-Day")!) {
						HStack {
							Text("View Source on GitHub")
							Image(systemName: "arrow.up.forward.square")
								.accessibilityHidden(true)
						}
					}
				} header: {
					SectionTitle("v\(Bundle.main.versionName) build \(Bundle.main.versionNumber)")
				}
			}
				.navigationTitle("About")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						ToolbarButtonView("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
		}
	}
}

#Preview {
	AboutView()
}
