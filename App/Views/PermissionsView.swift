import Photos
import SwiftUI

struct PermissionsView: View {
	private var state = StateManager.shared

	@State private var showPrivacy = false

	@Environment(\.openURL) private var openURL

	private func openSettings() {
		openURL(.photoPrivacySettings)
	}

	var body: some View {
		if state.permission != .authorized && state.permission != .notDetermined {
			ZStack {
				RoundedRectangle(cornerRadius: 48, style: .continuous)
					.fill(.fill.secondary)
					.onTapGesture(perform: openSettings)
					// The Settings button does the same for VoiceOver.
					.accessibilityHidden(true)
				VStack {
					Label(state.permission == .limited ? "Photos Limited" : "Photos Unavailable", systemImage: "photo")
						.font(.headline)
						.padding(.bottom, 1)
						.accessibilityAddTraits(.isHeader)
					VStack(alignment: .leading, spacing: 8) {
						if state.permission == .limited {
							Text("You're currently limiting access to photos from your library. This isn't recommended since new photos will not be automatically included.")
							Text("Note that photos you mark as **Hidden** from Photos.app are never displayed or even accessed by this app.")
								.font(.callout.italic())
						} else {
							Text("_Photos On This Day_ does not have permission to access your photo library, which prevents the Widget and App from displaying your photos.")
							if state.permission == .restricted {
								Text("Please enable apps to access photos with permission via Settings.app.")
							} else {
								Text("Please set photo access to \"**Full Access**\" in Settings.")
							}
						}
					}
					HStack {
						Button {
							showPrivacy.toggle()
						} label: {
							Label("Privacy", systemImage: "lock.shield.fill")
								.padding(4)
						}
						Link(destination: .photoPrivacySettings) {
							Label("Settings", systemImage: "gear")
								.padding(4)
						}
					}
						.font(.headline)
				}
					.buttonStyle(.bordered)
					.padding(20)
			}
				.confirmationDialog("Privacy First", isPresented: $showPrivacy, titleVisibility: .visible) {
					Link(destination: .photoPrivacySettings) {
						Label("Go to Settings", systemImage: "gear")
					}
						.font(.headline)
						.labelStyle(.titleAndIcon)
				} message: {
					Text("Your privacy is of the utmost importance. Photos are only used to display in the Widget and App UI. This app never stores or uploads your photos anywhere, and only changes your photo library when you favorite a photo.")
				}
		}
	}
}

#Preview {
	PermissionsView()
		.padding()
}
