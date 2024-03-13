import SwiftUI

struct ShowHelpView: View {
	@AppStorage(UserDefaults.Key.dismissedAddWidget) private var dismissedAddWidget = false
	@Environment(\.scenePhase) private var scenePhase

	@State private var showAddWidgetHelp = false

	var body: some View {
		Group {
			if !dismissedAddWidget {
				Button {
					showAddWidgetHelp.toggle()
				} label: {
					Text("Add a Widget to your Home Screen!")
						.font(.title3.weight(.medium))
						.padding(8)
				}
					.buttonStyle(.bordered)
					.padding()
					.sheet(isPresented: $showAddWidgetHelp) {
						NavigationView {
							HelpAddWidgetView(inSheet: true)
						}
						.navigationViewStyle(.stack)
					}
					.onChange(of: scenePhase) { oldPhase, newPhase in
						switch newPhase {
						case .active:
							UserDefaults.shared.updateAddedWidget()
						default: break
						}
					}
			}
		}
	}
}

#Preview {
	ShowHelpView()
}
