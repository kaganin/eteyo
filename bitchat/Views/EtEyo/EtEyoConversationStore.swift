import SwiftUI

#if os(iOS)
/// Stable destinations keep similarly named people and location channels separate.
enum EtEyoConversation: Hashable, Codable {
    case location(String)
    case person(Int, String)

    var id: String {
        switch self {
        case .location(let name): return "location:\(name)"
        case .person(let id, _): return "person:\(id)"
        }
    }

    var title: String {
        switch self {
        case .location(let name), .person(_, let name): return name
        }
    }
}

struct EtEyoLocalMessage: Identifiable, Codable {
    var id = UUID()
    let text: String
    var date = Date()
}

struct EtEyoConversationDraft: Codable {
    var text = ""
    var command: String?
    var messages: [EtEyoLocalMessage] = []
}

/// Local UI prototype data, deliberately separate from Bitchat's transports.
@MainActor
final class EtEyoConversationStore: ObservableObject {
    @Published private var conversations: [String: EtEyoConversationDraft]
    private let defaults: UserDefaults
    private let key = "eteyo.conversationPreviews.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        conversations = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([String: EtEyoConversationDraft].self, from: $0) } ?? [:]
    }

    func draft(for destination: EtEyoConversation) -> EtEyoConversationDraft {
        conversations[destination.id] ?? EtEyoConversationDraft()
    }

    func update(_ draft: EtEyoConversationDraft, for destination: EtEyoConversation) {
        conversations[destination.id] = draft
    }

    func send(to destination: EtEyoConversation) {
        var draft = draft(for: destination)
        let text = [draft.command, draft.text.trimmingCharacters(in: .whitespacesAndNewlines)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        guard !text.isEmpty else { return }
        draft.messages.append(EtEyoLocalMessage(text: text))
        draft.text = ""
        draft.command = nil
        update(draft, for: destination)
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        defaults.set(data, forKey: key)
    }
}
#endif
