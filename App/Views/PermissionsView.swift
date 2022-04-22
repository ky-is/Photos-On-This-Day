import SwiftUI
import PhotosUI

struct PermissionsView: View {
	@ObservedObject private var permissions = PermissionsManager.shared

	var body: some View {
		if PermissionsManager.shared.permission != .authorized {
			ZStack {
				RoundedRectangle(cornerRadius: 48, style: .continuous)
					.fill(Color(uiColor: .secondarySystemFill))
				VStack {
					if PermissionsManager.shared.permission == .limited {
						Text("Photo Access Unavailable")
							.font(.headline)
							.padding(.bottom, 2)
						Text("You're currently allowing a limited number of photos from your library. This isn't recommended since new photos will not be automatically included. Note that Hidden photos are never accessed or displayed through this app.")
						Button("Manage limited photos") {
							if let viewController = UIApplication.shared.frontViewController {
								PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
							} else {
								UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
							}
						}
					} else {
						Text("Photo Access Unavailable")
							.font(.headline)
							.padding(.bottom)
						Text("Photos On This Day does not have permission to access your photo library, which prevents your photos from being show in the Widget or App.")
						if PermissionsManager.shared.permission == .restricted {
							Text("Please enable apps to access photos with permission via Settings.app.")
						} else {
							Text("Please update the Photos permission in Settings.app.")
						}
					}
					Link("Go to Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
				}
				.buttonStyle(.bordered)
				.padding(24)
			}
		}
	}
}

struct PermissionsView_Previews: PreviewProvider {
	static var previews: some View {
		PermissionsView()
	}
}
