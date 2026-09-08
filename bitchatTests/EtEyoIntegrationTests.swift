#if os(iOS)
import BitFoundation
import Combine
import Foundation
import Testing
@testable import bitchat

@MainActor
struct EtEyoIntegrationTests {
    @Test func conversationsWithIdenticalLabelsHaveSeparateDrafts() {
        let first = EtEyoConversation.location(GeohashChannel(level: .city, geohash: "u33dc"))
        let second = EtEyoConversation.location(GeohashChannel(level: .city, geohash: "gcpvj"))
        let alice = EtEyoConversation.person(PeerID(str: "0000000000000001"), "anon")
        let bob = EtEyoConversation.person(PeerID(str: "0000000000000002"), "anon")
        let drafts = EtEyoConversationStore()
        drafts.update("Berlin draft", for: first)
        drafts.update("London draft", for: second)
        drafts.update("Alice draft", for: alice)
        #expect(drafts.text(for: first) == "Berlin draft")
        #expect(drafts.text(for: second) == "London draft")
        #expect(drafts.text(for: bob).isEmpty)
        let renamedAlice = EtEyoConversation.person(PeerID(str: "0000000000000001"), "renamed")
        #expect(drafts.text(for: renamedAlice) == "Alice draft")
        drafts.clear()
        #expect(drafts.text(for: first).isEmpty)
        #expect(drafts.text(for: alice).isEmpty)
    }

    @Test func routingRejectsStaleChannelAndWrongPrivateRecipient() {
        let berlin = GeohashChannel(level: .city, geohash: "u33dc")
        let london = GeohashChannel(level: .city, geohash: "gcpvj")
        let peer = PeerID(str: "0000000000000001")
        #expect(!EtEyoConversation.mesh.matches(channel: .location(berlin), peerID: nil))
        #expect(!EtEyoConversation.mesh.matches(channel: .mesh, peerID: peer))
        #expect(!EtEyoConversation.location(berlin).matches(channel: .location(london), peerID: nil))
        #expect(EtEyoConversation.location(berlin).matches(channel: .location(berlin), peerID: nil))
        #expect(!EtEyoConversation.person(peer, "alice").matches(channel: .mesh, peerID: nil))
        #expect(!EtEyoConversation.person(peer, "alice").matches(channel: .mesh, peerID: PeerID(str: "0000000000000002")))
        #expect(EtEyoConversation.person(peer, "alice").matches(channel: .location(london), peerID: peer))
    }

    @Test func publicTimelineRetargetsWithoutCopyingOtherChannels() {
        let store = ConversationStore()
        let model = PublicChatModel(conversations: store)
        let berlin = GeohashChannel(level: .city, geohash: "u33dc")
        let london = GeohashChannel(level: .city, geohash: "gcpvj")
        store.append(message("mesh"), to: ConversationID(channelID: .mesh))
        store.append(message("berlin"), to: ConversationID(channelID: .location(berlin)))
        store.append(message("london"), to: ConversationID(channelID: .location(london)))
        #expect(model.messages.map(\.id) == ["mesh"])
        store.setActiveChannel(.location(berlin))
        #expect(model.messages.map(\.id) == ["berlin"])
        store.append(message("incoming"), to: ConversationID(channelID: .location(berlin)))
        #expect(model.messages.map(\.id) == ["berlin", "incoming"])
        store.setActiveChannel(.location(london))
        #expect(model.messages.map(\.id) == ["london"])
    }

    @Test func privateTimelineTracksIncomingReadAndDeliveryEvents() {
        let store = ConversationStore()
        let inbox = PrivateInboxModel(conversations: store)
        let peer = PeerID(str: "0000000000000001")
        let other = PeerID(str: "0000000000000002")
        let id = ConversationID.directPeer(peer)
        store.setSelectedPrivatePeer(peer)
        store.append(message("private", isPrivate: true), to: id)
        store.append(message("unrelated", isPrivate: true), to: .directPeer(other))
        #expect(inbox.messages(for: peer).map(\.id) == ["private"])
        store.markUnread(.directPeer(other))
        #expect(inbox.unreadPeerIDs.contains(other))
        store.markRead(.directPeer(other))
        #expect(!inbox.unreadPeerIDs.contains(other))
        var updates = 0
        let observation = inbox.objectWillChange.sink { updates += 1 }
        store.setDeliveryStatus(.sent, forMessageID: "private", in: id)
        #expect(inbox.messages(for: peer).last?.deliveryStatus == .sent)
        #expect(updates > 0)
        withExtendedLifetime(observation) {}
        store.clear(id)
        #expect(inbox.messages(for: peer).isEmpty)
        #expect(inbox.messages(for: other).count == 1)
    }

    @Test func fineLocationPresenceRemainsUnknownWhenSuppressed() {
        #expect(EtEyoLabels.people(0, level: .block) == "? people")
        #expect(EtEyoLabels.people(0, level: .neighborhood) == "? people")
        #expect(EtEyoLabels.people(0, level: .city) == "0 people")
        #expect(EtEyoLabels.people(1, level: .city) == "1 person")
        #expect(EtEyoLabels.people(4, level: .region) == "4 people")
    }

    private func message(_ id: String, isPrivate: Bool = false) -> BitchatMessage {
        BitchatMessage(id: id, sender: "alice", content: id, timestamp: Date(),
                       isRelay: false, isPrivate: isPrivate)
    }
}
#endif
