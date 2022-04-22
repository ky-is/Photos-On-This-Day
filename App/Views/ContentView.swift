import SwiftUI

struct ContentView: View {
	@ObservedObject private var permissions = PermissionsManager.shared

	var body: some View {
		NavigationView {
			ScrollView {
				PermissionsView()
					.padding()
				if permissions.permission == .authorized || permissions.permission == .limited {
					PhotosView()
				}
			}
		}
			.navigationViewStyle(.stack)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

