#if os(iOS)
import Foundation
import Testing
@testable import bitchat

struct EtEyoTimelineTests {
    @Test func incomingMessagesDoNotMoveSomeoneReadingHistory() {
        var state = EtEyoTimelineState()
        let shouldScroll1 = state.updateMessages(ids: ["a", "b"], latestIsOwn: false)
        #expect(shouldScroll1)
        state.updateViewport(isNearBottom: false)
        let shouldScroll2 = state.updateMessages(ids: ["a", "b", "c", "d"], latestIsOwn: false)
        #expect(!shouldScroll2)
        #expect(!state.followsLatest)
        #expect(state.unseenCount == 2)
        // A delivery-status refresh must not count the same arrival twice.
        let shouldScroll3 = state.updateMessages(ids: ["a", "b", "c", "d"], latestIsOwn: false)
        #expect(!shouldScroll3)
        #expect(state.unseenCount == 2)
        state.updateViewport(isNearBottom: true)
        #expect(state.unseenCount == 0)
        let shouldScroll4 = state.updateMessages(ids: ["a", "b", "c", "d", "e"], latestIsOwn: false)
        #expect(shouldScroll4)
    }

    @Test func sendingReturnsToLatestButDeliveryChangesDoNot() {
        var state = EtEyoTimelineState()
        _ = state.updateMessages(ids: ["own"], latestIsOwn: true)
        state.updateViewport(isNearBottom: false)
        let shouldScroll5 = state.updateMessages(ids: ["own"], latestIsOwn: true)
        #expect(!shouldScroll5)
        #expect(!state.followsLatest)
        let shouldScroll6 = state.updateMessages(ids: ["own", "new-own"], latestIsOwn: true)
        #expect(shouldScroll6)
        #expect(state.followsLatest)
    }

    @Test func clearingAndRemovingMessagesKeepTheCounterAccurate() {
        var state = EtEyoTimelineState()
        _ = state.updateMessages(ids: ["a"], latestIsOwn: false)
        state.updateViewport(isNearBottom: false)
        _ = state.updateMessages(ids: ["a", "b", "c"], latestIsOwn: false)
        let shouldScroll7 = state.updateMessages(ids: ["a", "c"], latestIsOwn: false)
        #expect(!shouldScroll7)
        #expect(state.unseenCount == 1)
        let shouldScroll8 = state.updateMessages(ids: [], latestIsOwn: false)
        #expect(!shouldScroll8)
        #expect(state.unseenCount == 0)
        let shouldScroll9 = state.updateMessages(ids: ["first"], latestIsOwn: false)
        #expect(shouldScroll9)
    }

    @Test func messageLinksDoNotInterpretMarkdownOrActivateCustomSchemes() {
        let text = "[bank](bitchat://share) **literal** https://example.com/hello"
        let result = EtEyoMessageText.attributed(text)
        #expect(String(result.characters) == text)
        #expect(result.runs.compactMap(\.link) == [URL(string: "https://example.com/hello")!])
    }
}
#endif
