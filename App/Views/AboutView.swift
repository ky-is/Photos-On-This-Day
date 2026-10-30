import SwiftUI

private let appStoreURL = URL(string: "https://apps.apple.com/app/photos-on-this-day/id1620659723")!

struct AboutView: View {
	@Environment(\.dismiss) private var dismiss

	private var filters = Filters.shared

	var body: some View {
		NavigationStack {
			Form {
				Section("Help") {
					NavigationLink("How to add a Widget") {
						HelpAddWidgetView(inSheet: false)
					}
				}
				if !filters.hiddenPhotos.isEmpty {
					Section("Manage") {
						NavigationLink("Hidden photos") {
							HelpHiddenPhotos()
						}
					}
				}
				Section("Share") {
					Link(destination: URL(string: "\(appStoreURL.absoluteString)?action=write-review")!) {
						HStack {
							Text("Rate _Photos On This Day_")
							Image(systemName: "arrow.up.forward.square")
						}
					}
					ShareLink(item: appStoreURL) {
						Text("Share with a friend...")
					}
				}
				Section("v\(Bundle.main.versionName) build \(Bundle.main.versionNumber)") {
					Link(destination: URL(string: "https://github.com/ky-is/Photos-On-This-Day")!) {
						HStack {
							Text("View Source on GitHub")
							Image(systemName: "arrow.up.forward.square")
						}
					}
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
