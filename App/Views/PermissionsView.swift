import SwiftUI

struct PermissionsView: View {
	@ObservedObject private var permissions = PermissionsManager.shared

	@State private var showPrivacy = false

	private func openSettings() {
		UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
	}

	var body: some View {
		if permissions.permission != .authorized && permissions.permission != .notDetermined {
			ZStack {
				RoundedRectangle(cornerRadius: 48, style: .continuous)
					.fill(Color(uiColor: .secondarySystemFill))
					.onTapGesture {
						openSettings()
					}
				VStack {
					Label("Access \(permissions.permission == .limited ? "Limited" : "Unavailable")", systemImage: "photo")
						.font(.system(.headline, design: .rounded))
						.padding(.bottom, 1)
					VStack(alignment: .leading, spacing: 8) {
						if permissions.permission == .limited {
							Text("You're currently limiting access to photos from your library. This isn't recommended since new photos will not be automatically included.")
							Text("Note that photos you mark as **Hidden** from Photos.app are never displayed or even accessed by this app.")
								.font(.callout.italic())
						} else {
							Text("_Photos On This Day_ does not have permission to access your photo library, which prevents the Widget and App from displaying your photos.")
							if permissions.permission == .restricted {
								Text("Please enable apps to access photos with permission via Settings.app.")
							} else {
								Text("Please allow photos access to \"**All Photos**\" in Settings.app.")
							}
							Text("Your privacy is of the utmost importance. Photos are only used to display in the widget and app UI. This app never stores or uploads your photos anywhere, nor does it make any changes to your photo library.")
								.font(.callout.italic())
						}
					}
					HStack {
						Button {
							showPrivacy.toggle()
						} label: {
							Label("Privacy", systemImage: "lock.shield.fill")
								.padding(4)
						}
						Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
							Label("Settings", systemImage: "gear")
								.padding(4)
						}
					}
						.font(.system(.headline, design: .rounded))
				}
					.buttonStyle(.bordered)
					.padding(20)
			}
				.confirmationDialog("Privacy First", isPresented: $showPrivacy, titleVisibility: .visible) {
					Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
						Label("Go to Settings", systemImage: "gear")
					}
						.font(.system(.headline, design: .rounded))
						.labelStyle(.titleAndIcon)
				} message: {
					Text("Your privacy is of the utmost importance. Photos are only used to display in the widget and app UI. This app never stores or uploads your photos anywhere, nor does it make any changes to your photo library.")
				}
		}
	}
}

struct PermissionsView_Previews: PreviewProvider {
	static var previews: some View {
		PermissionsView()
	}
}
