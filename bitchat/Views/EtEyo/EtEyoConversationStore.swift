import BitFoundation
import SwiftUI

#if os(iOS)
/// Routing identities include the full geohash or peer ID, never a display name.
enum EtEyoConversation: Hashable, Identifiable {
    case mesh
    case location(GeohashChannel)
    case person(PeerID, String)

    var id: String {
        switch self {
        case .mesh: return "mesh"
        case .location(let channel): return "geohash:\(channel.geohash)"
        case .person(let peer, _): return "direct:\(peer.id)"
        }
    }

    var title: String {
        switch self {
        case .mesh: return "mesh"
        case .location(let channel): return channel.level.eteyoTitle
        case .person(_, let name): return name
        }
    }

    var publicChannel: ChannelID? {
        switch self {
        case .mesh: return .mesh
        case .location(let channel): return .location(channel)
        case .person: return nil
        }
    }

    func matches(channel: ChannelID, peerID: PeerID?) -> Bool {
        switch self {
        case .mesh: return peerID == nil && channel == .mesh
        case .location(let expected): return peerID == nil && channel == .location(expected)
        case .person(let expected, _): return peerID == expected
        }
    }
}

/// Only unsent text lives here, in memory. Bitchat owns every message timeline.
@MainActor
final class EtEyoConversationStore: ObservableObject {
    @Published private var drafts: [String: String] = [:]

    func text(for destination: EtEyoConversation) -> String { drafts[destination.id] ?? "" }

    func update(_ text: String, for destination: EtEyoConversation) {
        if text.isEmpty { drafts.removeValue(forKey: destination.id) }
        else { drafts[destination.id] = text }
    }

    func clear() { drafts.removeAll() }
}

extension GeohashChannelLevel {
    var eteyoTitle: String {
        switch self {
        case .building: return "building"
        case .block: return "block"
        case .neighborhood: return "neighbourhood"
        case .city: return "city"
        case .province: return "province"
        case .region: return "region"
        }
    }
}

enum EtEyoLabels {
    static func people(_ count: Int, level: GeohashChannelLevel? = nil) -> String {
        // Fine-grained channels suppress presence broadcasts for privacy.
        if count == 0, let level, level.precision >= 6 { return "? people" }
        return count == 1 ? "1 person" : "\(count) people"
    }

    static func preview(_ message: BitchatMessage, nickname: String) -> String {
        if let media = message.mediaAttachment(for: nickname) {
            switch media {
            case .image: return "Photo"
            case .voice: return "Voice message"
            }
        }
        return message.content.replacingOccurrences(of: "\n", with: " ")
    }
}
#endif
