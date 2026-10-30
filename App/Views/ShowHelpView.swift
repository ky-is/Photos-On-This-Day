import SwiftUI
import WidgetKit
import os

struct ShowHelpView: View {
	@AppStorage(UserDefaults.Key.dismissedAddWidget) private var dismissedAddWidget = false
	@Environment(\.scenePhase) private var scenePhase

	@State private var showAddWidgetHelp = false

	var body: some View {
		if !dismissedAddWidget {
			Button {
				showAddWidgetHelp.toggle()
			} label: {
				title
					.font(.title3.weight(.medium))
					.padding(8)
			}
				.buttonStyle(.bordered)
				.padding()
				.sheet(isPresented: $showAddWidgetHelp) {
					NavigationStack {
						HelpAddWidgetView(inSheet: true)
					}
				}
				.task(id: scenePhase) {
					guard scenePhase == .active else { return }
					await dismissIfWidgetAdded()
				}
		}
	}

	private var title: Text {
		#if os(macOS)
		Text("Add a Widget to your Desktop!")
		#else
		Text("Add a Widget to your Home Screen!")
		#endif
	}

	/// Stops suggesting the widget once one is on the Home Screen or desktop.
	private func dismissIfWidgetAdded() async {
		do {
			if try await !WidgetCenter.shared.currentConfigurations().isEmpty {
				dismissedAddWidget = true
			}
		} catch {
			logger.error("Widget configurations: \(error.localizedDescription)")
		}
	}
}

#Preview {
	ShowHelpView()
}
