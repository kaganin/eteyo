import Foundation

#if os(iOS)
/// Reading position is a user choice. Arrivals only follow while at the bottom;
/// sending a message is an explicit request to return to the live conversation.
struct EtEyoTimelineState {
    private(set) var followsLatest = true
    private(set) var unseenCount = 0
    private var knownIDs: Set<String> = []
    private var unseenIDs: Set<String> = []
    private var hasLoadedMessages = false

    mutating func updateViewport(isNearBottom: Bool) {
        followsLatest = isNearBottom
        if isNearBottom { returnToLatest() }
    }

    mutating func returnToLatest() {
        followsLatest = true
        unseenIDs.removeAll()
        unseenCount = 0
    }

    /// Returns whether the view should move to its bottom anchor.
    mutating func updateMessages(ids: [String], latestIsOwn: Bool) -> Bool {
        let current = Set(ids)
        let added = current.subtracting(knownIDs)
        knownIDs = current
        unseenIDs.formIntersection(current)
        unseenCount = unseenIDs.count
        guard !ids.isEmpty else {
            hasLoadedMessages = false
            returnToLatest()
            return false
        }
        let firstLoad = !hasLoadedMessages
        hasLoadedMessages = true
        guard !added.isEmpty else { return false }
        let ownArrival = latestIsOwn && ids.last.map(added.contains) == true
        if firstLoad || followsLatest || ownArrival {
            returnToLatest()
            return true
        }
        unseenIDs.formUnion(added)
        unseenCount = unseenIDs.count
        return false
    }
}
#endif
