import XCTest

/// Runs Xcode's accessibility audit (contrast, clipped text, Dynamic Type, hit regions, labels, traits) on every screen. Run in the simulator,
/// on its sample photo library: `-screenshotDate` picks August 8, which has three photos from 2012.
///
/// Every issue on a screen is listed before the test fails, so one run shows them all. Skipped, as the audit can't judge them:
/// - Contrast of anything on or under glass (nav bar buttons, rows scrolled beneath a bar): glass takes its color from whatever is
///   behind it, and the audit samples one frame.
/// - Dynamic Type and clipping on bar buttons, which keep a fixed size like the system's in a fixed-height bar and show the Large
///   Content Viewer on a long press instead.
/// - Dynamic Type, clipping and contrast of the text on the collage card: the card is the share image itself, drawn at a fixed size so
///   the saved image looks the same everywhere, and its text sits on photos and a gradient the audit can't sample. VoiceOver reads it
///   through the header's combined label and each tile's label instead.
/// Issues the audit can't tie to an element are printed but don't fail, since there's nothing to point a fix at.
nonisolated final class AccessibilityAuditTests: XCTestCase {
	/// The day in the simulator's sample library with photos from a past year.
	private static let day = ["-screenshotDate", "2022-08-08T18:00:00Z"]

	/// Labels whose issue type the audit misreports, checked by hand. Each says how it was checked.
	private static let checkedByHand: [(XCUIAccessibilityAuditType, @Sendable (String) -> Bool)] = [
		// Year headers ("2012, 3 photos"): their row height scales with the text (@ScaledMetric), so the audit's fixed-frame guess is
		// wrong. Checked at accessibility-extra-extra-extra-large: the whole year shows and the photos move down.
		(.textClipped, { $0.range(of: #"^\d{4}, "#, options: .regularExpression) != nil }),
		// About's version line, a grouped list's section title: flagged "partially unsupported" however it's laid out, though it
		// follows the text size like the other section titles.
		(.dynamicType, { $0.hasPrefix("v") && $0.contains(" build ") }),
	]

	@MainActor
	func testGrid() throws {
		let app = launch(Self.day)
		try audit(app, "Grid")
	}

	@MainActor
	func testViewer() throws {
		let app = launch(Self.day + ["-screenshotViewer", "YES"], waitForGrid: false)
		// The viewer opens on its own once the grid has loaded.
		XCTAssert(app.buttons["Favorite"].firstMatch.waitForExistence(timeout: 10), "No viewer")
		try audit(app, "Viewer")
	}

	@MainActor
	func testSlideshow() throws {
		let app = launch(Self.day)
		openMenuItem(app, menu: "More", item: "Slideshow")
		sleep(2)
		try audit(app, "Slideshow")
	}

	@MainActor
	func testCollagePost() throws {
		let app = launch(Self.day + ["-screenshotCollage", "YES"])
		waitForShare(app)
		try audit(app, "Collage post")
	}

	@MainActor
	func testCollageStory() throws {
		let app = launch(Self.day + ["-screenshotCollage", "YES"])
		waitForShare(app)
		// The segmented picker's second segment; tapping it by label makes the test scroll first, which fails on a segment.
		app.segmentedControls.buttons.element(boundBy: 1).tap()
		waitForShare(app)
		try audit(app, "Collage story")
	}

	@MainActor
	func testCollageVideo() throws {
		let app = launch(Self.day + ["-screenshotCollage", "YES", "-screenshotCollageFormat", "video"])
		waitForShare(app, timeout: 30)
		try audit(app, "Collage video")
	}

	@MainActor
	func testAbout() throws {
		let app = launch(Self.day)
		openMenuItem(app, menu: "Filters", item: "About")
		XCTAssert(app.navigationBars["About"].waitForExistence(timeout: 5), "No About screen")
		try audit(app, "About")
	}

	@MainActor
	func testWidgetHelp() throws {
		let app = launch(Self.day)
		openMenuItem(app, menu: "Filters", item: "About")
		let help = app.buttons["How to add a Widget"].firstMatch
		XCTAssert(help.waitForExistence(timeout: 5), "No widget help link")
		help.tap()
		XCTAssert(app.navigationBars["Add a Widget"].waitForExistence(timeout: 5), "No widget help screen")
		try audit(app, "Widget help")
	}

	@MainActor
	func testHiddenAlbums() throws {
		let app = launch(Self.day)
		openMenuItem(app, menu: "Filters", item: "Hide Albums")
		sleep(2)
		try audit(app, "Hidden albums")
	}

	@MainActor
	private func launch(_ arguments: [String], waitForGrid: Bool = true) -> XCUIApplication {
		continueAfterFailure = true
		let app = XCUIApplication()
		app.launchArguments += arguments
		app.launch()
		if waitForGrid {
			XCTAssert(app.navigationBars["August 8"].waitForExistence(timeout: 10), "App didn't show August 8")
		}
		return app
	}

	@MainActor
	private func openMenuItem(_ app: XCUIApplication, menu: String, item: String) {
		let button = app.buttons[menu].firstMatch
		XCTAssert(button.waitForExistence(timeout: 5), "No \(menu) menu")
		button.tap()
		let entry = app.buttons[item].firstMatch
		XCTAssert(entry.waitForExistence(timeout: 5), "No \(item) in \(menu)")
		entry.tap()
	}

	/// The collage's Share button is enabled once the card or video is ready.
	@MainActor
	private func waitForShare(_ app: XCUIApplication, timeout: TimeInterval = 10) {
		let share = app.buttons["Share"].firstMatch
		let ready = expectation(for: NSPredicate(format: "exists == true AND enabled == true"), evaluatedWith: share)
		wait(for: [ready], timeout: timeout)
	}

	/// Audits the screen showing, failing once with every issue found
	@MainActor
	private func audit(_ app: XCUIApplication, _ screen: String) throws {
		var issues: [String] = []
		// The glass nav bars at the top; this app has no bottom bar outside of select mode.
		let topBars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
		let card = app.descendants(matching: .any).matching(identifier: "CollageCard").firstMatch
		let cardFrame = card.exists ? card.frame : .null
		try app.performAccessibilityAudit { issue in
			guard let element = issue.element else {
				print("AUDIT (not failing, no element) [\(screen)] \(issue.compactDescription): \(issue.detailedDescription)")
				return true
			}
			let frame = element.frame
			let isBarButton = element.elementType == .button && topBars.contains { $0.contains(frame) }
			let onGlass = isBarButton || topBars.contains { $0.intersects(frame) }
			let onCard = cardFrame.contains(frame)
			switch issue.auditType {
			case .contrast where onGlass, .dynamicType where isBarButton, .textClipped where isBarButton:
				print("AUDIT (skipped, glass bar) [\(screen)] \(issue.compactDescription) — '\(element.label)'")
			case .dynamicType where onCard, .textClipped where onCard, .contrast where onCard:
				print("AUDIT (skipped, share image) [\(screen)] \(issue.compactDescription) — '\(element.label)'")
			case let type where Self.checkedByHand.contains { $0.0 == type && $0.1(element.label) }:
				print("AUDIT (skipped, checked by hand) [\(screen)] \(issue.compactDescription) — '\(element.label)'")
			default:
				issues.append("[\(screen)] \(issue.compactDescription) — \(element.elementType.rawValue) '\(element.label)': \(issue.detailedDescription)")
			}
			// Handled, so the audit keeps going and the rest are listed too
			return true
		}
		for issue in issues {
			print("AUDIT \(issue)")
		}
		XCTAssert(issues.isEmpty, "\(issues.count) accessibility issues on \(screen):\n" + issues.joined(separator: "\n"))
	}
}
