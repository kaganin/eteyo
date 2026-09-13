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
    @State private var timelineState = EtEyoTimelineState()
    @State private var composerHeight: CGFloat = 62
    @State private var notice: String?
    @State private var hasAppeared = false
    @State private var showPeople = false
    @State private var showPersonDetails = false
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

    private var isPersonTarget: Bool {
        if case .person = target { return true }
        return false
    }

    var body: some View {
        timeline
        .background(Color.black)
        .background(EtEyoNavigationAppearance())
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    if case .person = target,
                       privateChat.selectedHeaderState?.isGroupConversation == false {
                        focused = false
                        showPersonDetails = true
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(headerTitle).font(.system(size: 16, weight: .medium)).tracking(EtEyoTypography.tracking(for: 16)).foregroundStyle(.white)
                        Text(headerSubtitle).font(.system(size: 13)).tracking(EtEyoTypography.tracking(for: 13)).foregroundStyle(.secondary)
                    }
                    .lineLimit(1).frame(width: 174, height: 44)
                    .modifier(EtEyoGlassSurface(radius: 22, interactive: isPersonTarget))
                }
                .buttonStyle(.plain)
                .accessibilityHint(isPersonTarget ? "Shows contact details" : "")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("People", systemImage: "person.2") { focused = false; showPeople = true }
                    Button("Clear chat", systemImage: "trash", role: .destructive) { showClearConfirmation = true }
                        .disabled(!ready)
                } label: { Image("EtEyo-more").renderingMode(.template) }
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
        .sheet(isPresented: $showPersonDetails) {
            if let state = privateChat.selectedHeaderState, !state.isGroupConversation {
                EtEyoPersonDetailScreen(
                    state: state,
                    isBlocked: isSelectedPersonBlocked,
                    onBlock: {
                        ui.block(peerID: state.conversationPeerID, displayName: state.displayName)
                        privateChat.endConversation()
                    },
                    onUnblock: {
                        ui.unblock(peerID: state.conversationPeerID, displayName: state.displayName)
                    }
                )
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

    private var isSelectedPersonBlocked: Bool {
        guard let state = privateChat.selectedHeaderState else { return false }
        if state.conversationPeerID.isGeoChat || state.conversationPeerID.isGeoDM {
            return peers.geohashPeople.first(where: { PeerID(nostr_: $0.id) == state.conversationPeerID })?.isBlocked ?? false
        }
        return peers.meshRows.first(where: { $0.peerID == state.headerPeerID })?.isBlocked ?? false
    }

    private func markRead() {
        guard isActive, hasAppeared, ready, timelineState.followsLatest, scenePhase == .active,
              case .person(let peer, _) = target else { return }
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
        GeometryReader { viewport in
            let viewportHeight = viewport.size.height
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                EtEyoEmptyState(title: ready ? String(localized: "Start a conversation") : String(localized: "Opening conversation…"),
                                    detail: emptyConversationDetail)
                                    .padding(.top, 48)
                            }
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                if index == 0 || !Calendar.current.isDate(messages[index - 1].timestamp, inSameDayAs: message.timestamp) {
                                    Text(message.timestamp, format: .dateTime.day().month().year())
                                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                }
                                messageRow(message).id(message.id)
                            }
                        }
                        // Keep the anchor outside the lazy stack so geometry still exists
                        // while reading older messages far from the bottom.
                        Color.clear.frame(height: composerHeight + 1).id("bottom")
                            .onGeometryChange(for: Bool.self) { anchor in
                                anchor.frame(in: .named("eteyo.timeline")).maxY <= viewportHeight + 44
                            } action: { nearBottom in
                                guard nearBottom != timelineState.followsLatest else { return }
                                timelineState.updateViewport(isNearBottom: nearBottom)
                                if nearBottom { markRead() }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    EtEyoChatComposer(text: text, focused: $focused,
                        canSend: ready, canAttach: ready && isActive && ui.canSendMediaInCurrentContext,
                        send: sendMessage, attach: { focused = false; imageDestination = target },
                        sendVoiceNote: { url in
                            guard ready, isActive else { return }
                            ui.sendVoiceNote(at: url)
                        })
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                }
                .coordinateSpace(name: "eteyo.timeline")
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .bottomTrailing) {
                    if !timelineState.followsLatest && !messages.isEmpty {
                        Button { scrollToLatest(proxy, animated: true) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down")
                                Text(timelineState.unseenCount == 0
                                    ? String(localized: "Latest messages")
                                    : String(localized: "\(timelineState.unseenCount) new messages"))
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).frame(minHeight: 44)
                            .background(.white, in: Capsule()).foregroundStyle(.black)
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                        }
                        .buttonStyle(EtEyoPressStyle())
                        .accessibilityIdentifier("eteyo.latestMessages")
                        .padding(16)
                        .padding(.bottom, composerHeight)
                    }
                }
                .onAppear { observeMessages(proxy) }
                .onChange(of: messages.map(\.id)) { _ in observeMessages(proxy) }
                .onChange(of: composerHeight) { _ in
                    if timelineState.followsLatest { scrollToLatest(proxy, animated: false) }
                }
            }
        }
        .clipped()
    }

    private var emptyConversationDetail: String {
        switch target {
        case .mesh: return String(localized: "Say hello to people nearby. Messages travel over Bluetooth.")
        case .location: return String(localized: "This is a public conversation. Anyone in this channel can read and reply.")
        case .person: return String(localized: "Send a message to start chatting.")
        }
    }

    private func observeMessages(_ proxy: ScrollViewProxy) {
        let latestIsOwn = messages.last.map {
            ui.isSelfSender(peerID: $0.senderPeerID, displayName: $0.sender)
        } ?? false
        if timelineState.updateMessages(ids: messages.map(\.id), latestIsOwn: latestIsOwn) {
            scrollToLatest(proxy, animated: false)
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        if !timelineState.followsLatest || timelineState.unseenCount > 0 {
            timelineState.returnToLatest()
        }
        withAnimation(animated && !reduceMotion ? .easeOut(duration: 0.2) : nil) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        markRead()
    }

    @ViewBuilder private func messageRow(_ message: BitchatMessage) -> some View {
        if let media = ui.mediaAttachment(for: message) {
            MediaMessageView(message: message, media: media, imagePreviewURL: $imagePreviewURL)
        } else if message.sender == "system" {
            Text(message.content).font(.footnote).foregroundStyle(.secondary)
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        } else {
            let mine = ui.isSelfSender(peerID: message.senderPeerID, displayName: message.sender)
            HStack {
                if mine { Spacer(minLength: 36) }
                VStack(alignment: mine ? .trailing : .leading, spacing: 5) {
                    if !mine {
                        HStack(spacing: 5) {
                            Button {
                                if let peer = message.senderPeerID { privateChat.openConversation(for: peer) }
                            } label: { Text(message.sender).font(.footnote.weight(.medium)) }
                            .buttonStyle(.plain).disabled(message.senderPeerID == nil)
                            if ui.showsVerifiedSeal(for: message) {
                                Image(systemName: "checkmark.seal.fill").font(.caption)
                                    .accessibilityLabel("Verified sender")
                            }
                        }
                        .foregroundStyle(.secondary).padding(.horizontal, 12)
                    }
                    Text(EtEyoMessageText.attributed(message.content)).font(.body)
                        .tint(.white).textSelection(.enabled)
                        .padding(.horizontal, 15).padding(.vertical, 11)
                        .background(Color(white: mine ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 6) {
                        Text(message.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                        if mine && message.isPrivate { DeliveryStatusView(status: message.deliveryStatus) }
                    }.padding(.horizontal, 10)
                    if mine, case .failed = message.deliveryStatus {
                        Text(message.deliveryStatus.bitchatDescription).font(.caption).foregroundStyle(.red)
                        Button("Retry") { if ready { ui.resendFailedPrivateMessage(message) } }
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }
                }
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
                    if !mine, let peer = message.senderPeerID {
                        Button("Message privately", systemImage: "bubble.left") { privateChat.openConversation(for: peer) }
                        Button("Mention", systemImage: "at") {
                            let separator = text.wrappedValue.isEmpty || text.wrappedValue.last?.isWhitespace == true ? "" : " "
                            text.wrappedValue += separator + "@" + message.sender + " "
                            focused = true
                        }
                        Button("Block person", systemImage: "hand.raised", role: .destructive) {
                            ui.block(peerID: peer, displayName: message.sender)
                        }
                    }
                }
                if !mine { Spacer(minLength: 36) }
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        }
    }
}

/// Treat remote text as text, not Markdown. Only ordinary web links are tappable.
/// This avoids interpreting arbitrary URL schemes received from strangers.
enum EtEyoMessageText {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributed(_ text: String) -> AttributedString {
        let result = NSMutableAttributedString(string: text)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector?.matches(in: text, range: range) ?? [] {
            guard let url = match.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { continue }
            result.addAttribute(.link, value: url, range: match.range)
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
        return AttributedString(result)
    }
}
#endif
