import Testing
@testable import Photos_On_This_Day

struct ReviewPromptTests {
	@Test func onlyWithAWidget() {
		#expect(!ReviewPrompt.shouldAsk(today: "6/2/27", lastAsked: "", hasWidget: false))
		#expect(ReviewPrompt.shouldAsk(today: "6/2/27", lastAsked: "", hasWidget: true))
	}

	@Test func atMostOnceADay() {
		#expect(!ReviewPrompt.shouldAsk(today: "6/2/27", lastAsked: "6/2/27", hasWidget: true))
		#expect(ReviewPrompt.shouldAsk(today: "6/3/27", lastAsked: "6/2/27", hasWidget: true))
	}
}
