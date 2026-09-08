import BitFoundation
import SwiftUI

#if os(iOS)
struct EtEyoConversationScreen: View {
    let destination: EtEyoConversation
    @Binding var path: [EtEyoConversation]
    let open: (EtEyoConversation) -> Void
    @State private var target: EtEyoConversation
    @EnvironmentObject private var publicChat: PublicChatModel
    @EnvironmentObject private var privateChat: PrivateConversationModel
    @EnvironmentObject private var inbox: PrivateInboxModel
    @EnvironmentObject private var ui: ConversationUIModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var peers: PeerListModel
    @EnvironmentObject private var drafts: EtEyoConversationStore
    @EnvironmentObject private var chrome: AppChromeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var composerHeight: CGFloat = 68
    @State private var notice: String?
    @State private var hasAppeared = false
    @State private var showPeople = false
    @State private var showClearConfirmation = false
    @State private var imageDestination: EtEyoConversation?
    @State private var imagePreviewURL: URL?

    init(destination: EtEyoConversation, path: Binding<[EtEyoConversation]>, open: @escaping (EtEyoConversation) -> Void) {
        self.destination = destination
        _path = path
        self.open = open
        _target = State(initialValue: destination)
    }

    private var isActive: Bool { path.last?.id == destination.id }

    private var ready: Bool {
        target.matches(channel: publicChat.activeChannel, peerID: privateChat.selectedPeerID)
            && (target.publicChannel == nil || target.publicChannel == channels.selectedChannel)
    }

    private var headerTitle: String {
        if case .person = target { return privateChat.selectedHeaderState?.displayName ?? target.title }
        return target.title
    }

    private var headerSubtitle: String {
        guard ready else { return "Connecting…" }
        switch target {
        case .mesh: return EtEyoLabels.people(peers.reachableMeshPeerCount + 1)
        case .location(let channel):
            return EtEyoLabels.people(peers.participantCount(for: channel.geohash), level: channel.level)
        case .person(let peer, _):
            if let group = peers.groupRows.first(where: { $0.peerID == peer }) {
                return EtEyoLabels.people(group.memberCount)
            }
            switch privateChat.selectedHeaderState?.availability {
            case .bluetoothConnected: return "Bluetooth connected"
            case .meshReachable: return "Reachable via mesh"
            case .nostrAvailable: return "Available via internet"
            case .offline: return "Offline"
            case nil: return "Private chat"
            }
        }
    }

    private var messages: [BitchatMessage] {
        guard ready else { return [] }
        if case .person(let peer, _) = target { return inbox.messages(for: peer) }
        return publicChat.messages
    }

    private var text: Binding<String> {
        Binding(get: { drafts.text(for: target) }, set: { drafts.update($0, for: target) })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            timeline.padding(.bottom, composerHeight)
            EtEyoChatComposer(text: text, focused: $focused,
                canSend: ready, canAttach: ready && ui.canSendMediaInCurrentContext,
                send: sendMessage, attach: { focused = false; imageDestination = target },
                heightChanged: { composerHeight = $0 })
        }
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        .background(Color.black)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(headerTitle).font(.system(size: 15, weight: .medium)).tracking(0.1).foregroundStyle(.white)
                    Text(headerSubtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .lineLimit(1).frame(width: 174, height: 44)
                .modifier(EtEyoGlassSurface(radius: 22))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Commands", systemImage: "slash.circle") { text.wrappedValue = "/"; focused = true }
                    Button("People", systemImage: "person.2") { focused = false; showPeople = true }
                    Button("Clear chat", systemImage: "trash", role: .destructive) { showClearConfirmation = true }
                        .disabled(!ready)
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("More").accessibilityIdentifier("eteyo.more")
            }
        }
        .tint(.white)
        .onAppear(perform: activate)
        .onDisappear { hasAppeared = false }
        .onChange(of: isActive) { active in
            if active { activate() }
            else { hasAppeared = false; focused = false }
        }
        .onChange(of: privateChat.selectedPeerID) { peer in
            guard hasAppeared, isActive else { return }
            if let peer {
                // /msg, /group and notification routing all select through Bitchat.
                let conversation = EtEyoConversation.person(peer, privateChat.selectedHeaderState?.displayName ?? "Private chat")
                if conversation.id != target.id { open(conversation) }
            } else if case .person = target {
                dismiss()
            }
        }
        .onChange(of: ready) { if $0 { markRead() } }
        .onChange(of: messages.count) { _ in markRead() }
        .onChange(of: scenePhase) { if $0 == .active { markRead() } }
        .sheet(isPresented: $showPeople) {
            NavigationStack {
                EtEyoChatsScreen { conversation in
                    showPeople = false
                    open(conversation)
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPeople = false } } }
            }
        }
        .fullScreenCover(item: $imageDestination) { capturedTarget in
            ImagePickerView(sourceType: .photoLibrary) { image in
                imageDestination = nil
                guard let image else { return }
                guard ready, target.id == capturedTarget.id else {
                    notice = "The conversation changed. Select the photo again in the intended chat."
                    return
                }
                ui.processSelectedImage(image)
            }.ignoresSafeArea()
        }
        .sheet(isPresented: Binding(get: { imagePreviewURL != nil }, set: { if !$0 { imagePreviewURL = nil } })) {
            if let url = imagePreviewURL { ImagePreviewView(url: url) }
        }
        .confirmationDialog("Clear this chat?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear chat", role: .destructive) { if ready { ui.clearCurrentConversation() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the conversation's messages from this device.") }
        .alert("Chat", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .confirmationDialog("Send without private media encryption?", isPresented: Binding(
            get: { ui.legacyPrivateMediaConsentRequest != nil },
            set: { if !$0 { resolveMediaConsent(false) } }
        ), titleVisibility: .visible) {
            Button("Send visible file", role: .destructive) { resolveMediaConsent(true) }
            Button("Cancel", role: .cancel) { resolveMediaConsent(false) }
        } message: {
            Text("This peer's older client does not support encrypted private media. Mesh relays can see this file.")
        }
    }

    private func activate() {
        guard isActive else { return }
        hasAppeared = true
        guard !ready else {
            markRead()
            return
        }
        target = destination
        ui.setCurrentColorScheme(.dark)
        switch destination {
        case .mesh, .location:
            privateChat.endConversation()
            if let channel = destination.publicChannel { channels.select(channel) }
        case .person(let peer, _):
            privateChat.openConversation(for: peer)
            if let selected = privateChat.selectedPeerID {
                target = .person(selected, privateChat.selectedHeaderState?.displayName ?? destination.title)
            } else { notice = "This conversation is currently unavailable." }
        }
        markRead()
    }

    private func markRead() {
        guard isActive, hasAppeared, ready, scenePhase == .active, case .person(let peer, _) = target else { return }
        privateChat.markMessagesAsRead(from: peer)
    }

    private func sendMessage() {
        guard ready else { notice = "Wait for this conversation to finish connecting."; return }
        let value = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        // /nick belongs to app settings, not Bitchat's command processor.
        let parts = value.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        if parts.first?.lowercased() == "/nick" {
            guard parts.count == 2 else { notice = "Usage: /nick nickname"; return }
            chrome.setNickname(String(parts[1]))
            chrome.validateAndSaveNickname()
        } else { ui.sendMessage(value) }
        drafts.update("", for: target)
    }

    private func resolveMediaConsent(_ approved: Bool) {
        guard let request = ui.legacyPrivateMediaConsentRequest else { return }
        ui.resolveLegacyPrivateMediaConsent(requestID: request.id, approved: approved)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if messages.isEmpty {
                        EtEyoEmptyState(title: ready ? "No messages yet" : "Connecting…", detail: headerTitle)
                            .padding(.top, 40)
                    }
                    ForEach(messages, id: \.id) { message in
                        messageRow(message).id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.last?.id) { _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: composerHeight) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    @ViewBuilder private func messageRow(_ message: BitchatMessage) -> some View {
        if let media = ui.mediaAttachment(for: message) {
            MediaMessageView(message: message, media: media, imagePreviewURL: $imagePreviewURL)
        } else {
            let mine = ui.isSelfSender(peerID: message.senderPeerID, displayName: message.sender)
            HStack {
                if mine { Spacer(minLength: 40) }
                VStack(alignment: mine ? .trailing : .leading, spacing: 5) {
                    if !mine {
                        Button {
                            if let peer = message.senderPeerID { privateChat.openConversation(for: peer) }
                        } label: { Text(message.sender).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }
                        .buttonStyle(.plain).disabled(message.sender == "system" || message.senderPeerID == nil)
                    }
                    Text(message.content).font(.system(size: 16)).textSelection(.enabled)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 6) {
                        Text(message.timestamp, style: .time).font(.system(size: 11)).foregroundStyle(.secondary)
                        if mine && message.isPrivate { DeliveryStatusView(status: message.deliveryStatus) }
                    }
                    if mine, case .failed = message.deliveryStatus {
                        Text(message.deliveryStatus.bitchatDescription).font(.caption).foregroundStyle(.red)
                        Button("Retry") { if ready { ui.resendFailedPrivateMessage(message) } }.font(.caption)
                    }
                }
                if !mine { Spacer(minLength: 20) }
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        }
    }
}
#endif
