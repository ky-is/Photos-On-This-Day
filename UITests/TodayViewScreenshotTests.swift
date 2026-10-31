import XCTest

/// For the App Store widget screenshot (bin/app-store-screenshots.zsh): opens the Today View, the widget page left of the first
/// Home Screen page, and keeps it there while the script takes the screenshot. The script sets the widgets out beforehand and
/// passes how long to wait in `TEST_RUNNER_TODAY_VIEW_HOLD`; without it the test is skipped. Not for the iPhone Duo: XCTest's
/// touches reach neither of its screens in the simulator (its Home presses do).
nonisolated final class TodayViewScreenshotTests: XCTestCase {
	@MainActor
	func testShowTodayView() throws {
		let hold = ProcessInfo.processInfo.environment["TODAY_VIEW_HOLD"].flatMap(TimeInterval.init)
		try XCTSkipIf(hold == nil, "Run by bin/app-store-screenshots.zsh")
		let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
		// The script has just restarted SpringBoard so it reads the new widgets
		XCTAssert(springboard.wait(for: .runningForeground, timeout: 60), "SpringBoard isn't running")
		// Home twice: to the Home Screen, then to its first page, whose swipe right opens the Today View
		XCUIDevice.shared.press(.home)
		sleep(2)
		XCUIDevice.shared.press(.home)
		sleep(2)
		springboard.swipeRight()
		print("TODAY VIEW SHOWN")
		Thread.sleep(forTimeInterval: hold!)
	}
}
