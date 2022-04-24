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
						.font(.system(.title3, design: .rounded).weight(.medium))
						.padding(8)
				}
					.buttonStyle(.bordered)
					.padding(.horizontal)
					.sheet(isPresented: $showAddWidgetHelp) {
						NavigationView {
							HelpAddWidgetView(inSheet: true)
						}
						.navigationViewStyle(.stack)
					}
					.onChange(of: scenePhase) { newPhase in
						switch newPhase {
						case .active:
							UserDefaults.standard.updateAddedWidget()
						default: break
						}
					}
			}
		}
	}
}

struct ShowHelpView_Previews: PreviewProvider {
	static var previews: some View {
		ShowHelpView()
	}
}
