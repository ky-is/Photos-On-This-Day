import SwiftUI

struct AboutView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var loading = false
	@ObservedObject private var syncStorage = SyncStorage.shared

	var body: some View {
		NavigationView {
			Form {
				Section {
					NavigationLink {
						HelpAddWidgetView(inSheet: false)
					} label: {
						Text("How to add a Widget")
							.font(.system(.headline, design: .rounded))
					}
				} header: {
					Text("Help")
						.font(.system(.footnote, design: .rounded))
				}
				if !syncStorage.filterPhotos.isEmpty {
					Section {
						NavigationLink {
							HelpHiddenPhotos()
						} label: {
							Text("Hidden photos")
						}
					} header: {
						Text("Manage")
							.font(.system(.footnote, design: .rounded))
					}
				}
				Section {
					#if DEBUG //RELEASE
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
					#endif
				} header: {
					Text("Share")
						.font(.system(.footnote, design: .rounded))
				}
				Section {
				} header: {
					Text("About")
						.font(.system(.footnote, design: .rounded))
				} footer: {
					VStack(alignment: .leading) {
						Text("Photos On This Day")
							.font(.system(.headline, design: .rounded))
						Text("v\(Bundle.main.versionName) build \(Bundle.main.versionNumber)")
							.font(.system(.subheadline, design: .rounded))

					}
				}
			}
				.navigationTitle("About")
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						ToolbarButton("Close") {
							dismiss()
						}
							.keyboardShortcut(.cancelAction)
					}
				}
		}
			.navigationViewStyle(.stack)
	}
}

struct AboutView_Previews: PreviewProvider {
	static var previews: some View {
		AboutView()
	}
}
