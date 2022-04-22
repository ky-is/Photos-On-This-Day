import SwiftUI
import PhotosUI

struct ContentView: View {
	@ObservedObject private var permissions = PermissionsManager.shared

	var body: some View {
		ScrollView {
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
							if PermissionsManager.shared.permission == .restricted {
								Text("Photos On This Day does not have permission to access your photo library, which prevents your photos from being show in the Widget or App. Please enable apps to access photos with permission via Settings.app.")
							} else {
								Text("Photos On This Day does not have permission to access your photo library, which prevents your photos from being show in the Widget or App. Please update the Photos permission in Settings.app.")
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
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

