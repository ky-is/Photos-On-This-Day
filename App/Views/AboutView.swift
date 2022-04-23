import SwiftUI

struct AboutView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var loading = false

	var body: some View {
		NavigationView {
			Form {
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
					let url = URL(string: "https://apps.apple.com/app/kotoha/id\(Bundle.iTunesIdentifier)")!
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
				.navigationTitle("About")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
		}
	}
}

struct AboutView_Previews: PreviewProvider {
	static var previews: some View {
		AboutView()
	}
}