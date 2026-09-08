import SwiftUI

#if os(iOS)
struct EtEyoConversationScreen: View {
    let destination: EtEyoConversation
    let color: Color
    var participantSummary: String = "Private chat"
    @EnvironmentObject private var publicChat: PublicChatModel
    @EnvironmentObject private var privateChat: PrivateConversationModel
    @EnvironmentObject private var conversationUI: ConversationUIModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var peers: PeerListModel
    @State private var meshText = ""
    @State private var meshCommand: String?
    @EnvironmentObject private var store: EtEyoConversationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var composerHeight: CGFloat = 68
    @State private var previewNotice: String?

    private var isMesh: Bool { destination == .location("mesh") }

    private var headerSubtitle: String {
        guard isMesh else { return participantSummary }
        let count = peers.reachableMeshPeerCount + 1
        return count == 1 ? "1 person" : "\(count) people"
    }

    private struct TimelineMessage: Identifiable {
        let id: String
        let text: String
        let date: Date
        let sender: String
        let isMine: Bool
    }

    private var messages: [TimelineMessage] {
        if isMesh {
            guard publicChat.activeChannel == .mesh else { return [] }
            return publicChat.messages.map {
                TimelineMessage(id: $0.id, text: $0.content, date: $0.timestamp,
                                sender: $0.sender, isMine: conversationUI.isSentByCurrentUser($0))
            }
        }
        return draft.messages.map {
            TimelineMessage(id: $0.id.uuidString, text: $0.text, date: $0.date, sender: "", isMine: true)
        }
    }

    private func sendMessage() {
        guard isMesh else { store.send(to: destination); return }
        let value = meshText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard publicChat.activeChannel == .mesh, privateChat.selectedPeerID == nil else {
            previewNotice = "Reopen mesh before sending a message."
            return
        }
        let alias = value.split(whereSeparator: { $0.isWhitespace }).first?.lowercased()
        if alias == "/msg" || alias == "/group" {
            previewNotice = "Private and group chats will be connected in the next step."
            return
        }
        conversationUI.sendMessage(value)
        meshText = ""
    }

    private var draft: EtEyoConversationDraft { store.draft(for: destination) }

    private var text: Binding<String> {
        if isMesh { return $meshText }
        return Binding(get: { draft.text }, set: { value in
            var updated = draft
            updated.text = value
            store.update(updated, for: destination)
        })
    }

    private var command: Binding<String?> {
        if isMesh { return $meshCommand }
        return Binding(get: { draft.command }, set: { value in
            var updated = draft
            updated.command = value
            store.update(updated, for: destination)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                timeline
                    .padding(.bottom, composerHeight)

                EtEyoChatComposer(
                    text: text,
                    command: command,
                    focused: $focused,
                    send: sendMessage,
                    attach: { previewNotice = "Attachments aren't available in this preview yet." },
                    heightChanged: { composerHeight = $0 }
                )
            }
            .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        }
        .background(Color.black)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    focused = false
                    store.save()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("eteyo.back")
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(destination.title)
                        .font(.system(size: 15, weight: .medium))
                        .tracking(0.1)
                        .foregroundStyle(.white)
                    Text(headerSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: 174, height: 44)
                .modifier(EtEyoGlassSurface(radius: 22))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Commands", systemImage: "slash.circle") {
                        command.wrappedValue = nil
                        text.wrappedValue = "/"
                        focused = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
                .accessibilityIdentifier("eteyo.more")
            }
        }
        .tint(.white)
        .navigationBarBackButtonHidden()
        .onAppear {
            if isMesh {
                privateChat.endConversation()
                channels.select(.mesh)
            }
        }
        .onDisappear { store.save() }
        .onChange(of: scenePhase) { if $0 != .active { store.save() } }
        .alert("Preview", isPresented: Binding(
            get: { previewNotice != nil },
            set: { if !$0 { previewNotice = nil } }
        )) {
            Button("OK", role: .cancel) { previewNotice = nil }
        } message: {
            Text(previewNotice ?? "")
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(color)
                            Text("Start a conversation")
                                .font(.system(size: 17))
                            Text(destination.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                    }
                    ForEach(messages) { message in
                        HStack {
                            if message.isMine { Spacer(minLength: 40) }
                            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 5) {
                                if !message.isMine {
                                    Text(message.sender)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Text(message.text)
                                    .font(.system(size: 16))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                                Text(message.date, style: .time)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.count) { _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: composerHeight) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
}
#endif
