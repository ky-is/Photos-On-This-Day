import SwiftUI

struct ContentView: View {
	var body: some View {
		NavigationView {
			ScrollView {
				PermissionsView()
				PhotosView()
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

