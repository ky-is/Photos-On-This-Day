import SwiftUI

struct AboutView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var loading = false
	@AppStorage(UserDefaults.Key.filterPhotos) private var filterPhotos = [String: [String]]()

	var body: some View {
		NavigationView {
			Form {
				Section("Help") {
					NavigationLink {
						HelpAddWidgetView(inSheet: false)
					} label: {
						Text("How to add a Widget")
					}
				}
				if !filterPhotos.isEmpty {
					Section {
						NavigationLink {
							HelpHiddenPhotos()
						} label: {
							Text("Hidden photos")
						}
					} header: {
						Text("Manage")
					}
				}
				Section("Share") {
					UIViewButton { backing in
						openReviews()
					} label: {
						HStack {
							Text("Rate _Photos On This Day_")
							Image(systemName: "arrow.up.forward.square")
						}
					}
					UIViewButton { backing in
						loading = true
						let url = URL(string: "https://apps.apple.com/app/photos-on-this-day/id\(Bundle.iTunesIdentifier)")!
						if let vc = UIApplication.shared.frontViewController {
							let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
							activityController.popoverPresentationController?.sourceView = backing.uiView
							vc.present(activityController, animated: true, completion: nil)
						} else {
							UIPasteboard.general.url = url
						}
						loading = false
					} label: {
						Text("Share with a friend...")
					}
						.disabled(loading)
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
			.navigationViewStyle(.stack)
	}
}

#Preview {
	AboutView()
}
