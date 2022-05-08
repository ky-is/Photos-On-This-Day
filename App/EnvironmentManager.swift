import Photos
import WidgetKit
import SwiftUI

final class EnvironmentManager: ObservableObject {
	static let shared = EnvironmentManager()

	@Published var scenePhase: ScenePhase = .active
}
