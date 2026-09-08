import BitFoundation
import CoreBluetooth
import SwiftUI

#if os(iOS)
/// The eteyo shell shares Bitchat's runtime with the development reference tab.
struct EtEyoRootView: View {
    private enum Tab: Hashable {
        case locations, chats, settings
        #if DEBUG
        case debug
        #endif
    }

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var channels: LocationChannelsModel
    @State private var startupPermissions = EtEyoStartupPermissions()
    @State private var selectedTab: Tab = .locations
    @State private var destination: EtEyoConversation?
    @StateObject private var drafts = EtEyoConversationStore()
    @EnvironmentObject private var privateChat: PrivateConversationModel
    @EnvironmentObject private var chrome: AppChromeModel

    var body: some View {
        TabView(selection: $selectedTab) {
            EtEyoLocationsScreen(open: open)
                .tabItem { Label("Locations", systemImage: "location") }
                .tag(Tab.locations)
            EtEyoChatsScreen(open: open)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .badge(chrome.hasUnreadPrivateMessages ? "" : nil)
                .tag(Tab.chats)
            EtEyoSettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
            #if DEBUG
            ContentView()
                .tabItem { Label("Debug", systemImage: "wrench.and.screwdriver") }
                .tag(Tab.debug)
            #endif
        }
        .tint(.accentColor)
        .preferredColorScheme(.dark)
        .environmentObject(drafts)
        .onAppear(perform: requestStartupPermissions)
        .onChange(of: scenePhase) { _ in requestStartupPermissions() }
        .onChange(of: chrome.bluetoothState) { _ in requestStartupPermissions() }
        .fullScreenCover(item: $destination, onDismiss: {
            privateChat.endConversation()
        }) { conversation in
            NavigationStack {
                EtEyoConversationScreen(destination: conversation)
            }
            .environmentObject(drafts)
            .preferredColorScheme(.dark)
        }
        .onChange(of: privateChat.selectedPeerID) { peer in
            #if DEBUG
            guard selectedTab != .debug else { return }
            #endif
            // Notification and deep-link selections use the same conversation screen.
            guard destination == nil, let peer else { return }
            destination = .person(peer, privateChat.selectedHeaderState?.displayName ?? "Private chat")
        }
    }

    private func requestStartupPermissions() {
        guard !TestEnvironment.isRunningTests else { return }
        guard startupPermissions.takeLocationRequest(
            isActive: scenePhase == .active,
            bluetoothAuthorization: CBManager.authorization,
            bluetoothState: chrome.bluetoothState,
            locationPermission: channels.permissionState
        ) else { return }
        channels.enableAndRefresh()
    }

    private func open(_ conversation: EtEyoConversation) { destination = conversation }
}

struct EtEyoChatsScreen: View {
    var open: (EtEyoConversation) -> Void
    @EnvironmentObject private var peers: PeerListModel
    @EnvironmentObject private var ui: ConversationUIModel
    @EnvironmentObject private var inbox: PrivateInboxModel

    private var rows: [EtEyoChatRowData] {
        var rows: [EtEyoChatRowData] = []
        var seen = Set<PeerID>()
        func append(_ peer: PeerID, name: String, unread: Bool, color: Color, fallback: String, nostrPublicKey: String? = nil) {
            guard seen.insert(peer).inserted else { return }
            let last = peers.lastMessage(for: peer)
            rows.append(EtEyoChatRowData(peer: peer, name: name,
                message: last.map { EtEyoLabels.preview($0, nickname: ui.currentNickname) } ?? fallback,
                date: last?.timestamp, color: color, unread: unread, nostrPublicKey: nostrPublicKey))
        }
        for row in peers.meshRows where !row.isMe && !row.isBlocked {
            append(row.peerID, name: row.displayName, unread: row.hasUnread,
                   color: peers.colorForMeshPeer(id: row.peerID, isDark: true),
                   fallback: row.isConnected || row.isReachable ? "Available nearby" : "Offline")
        }
        for row in peers.geohashPeople where !row.isMe && !row.isBlocked {
            append(PeerID(nostr_: row.id), name: row.displayName, unread: inbox.unreadPeerIDs.contains(PeerID(nostr_: row.id)),
                   color: peers.colorForGeohashPerson(id: row.id, isDark: true), fallback: "In this channel", nostrPublicKey: row.id)
        }
        for row in peers.recentChatRows {
            append(row.peerID, name: row.displayName, unread: row.hasUnread,
                   color: peers.colorForMeshPeer(id: row.peerID, isDark: true), fallback: "No messages")
        }
        for row in peers.groupRows {
            append(row.peerID, name: row.name, unread: row.hasUnread,
                   color: .white, fallback: EtEyoLabels.people(row.memberCount))
        }
        return rows.sorted {
            if $0.date != $1.date { return ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            return $0.peer.id < $1.peer.id
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EtEyoScreenTitle("chats").padding(.bottom, 12)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if rows.isEmpty {
                        EtEyoEmptyState(title: "No chats yet", detail: "People discovered nearby or in your selected location channel appear here.")
                            .padding(.top, 40)
                    }
                    ForEach(rows) { row in
                        Button {
                            // Register the full key before opening the shortened GeoDM routing ID.
                            if let key = row.nostrPublicKey { peers.openGeohashDirectMessage(with: key) }
                            open(.person(row.peer, row.name))
                        } label: {
                            EtEyoChatRow(row: row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("eteyo.chat.\(row.peer.id)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }
}

private struct EtEyoChatRowData: Identifiable {
    let peer: PeerID
    let name: String
    let message: String
    let date: Date?
    let color: Color
    let unread: Bool
    let nostrPublicKey: String?
    var id: String { peer.id }
}

private struct EtEyoChatRow: View {
    let row: EtEyoChatRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.name.hasPrefix("@") || row.peer.isGroup ? row.name : "@" + row.name)
                    .font(.system(size: 15)).foregroundStyle(row.color).tracking(0.2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let date = row.date {
                    Text(date, style: .time).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 18)
            HStack {
                Text(row.message).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                if row.unread {
                    Circle().fill(.white).frame(width: 8, height: 8).accessibilityLabel("Unread messages")
                }
            }
            .frame(minHeight: 16)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct EtEyoLocationsScreen: View {
    var open: (EtEyoConversation) -> Void
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var peers: PeerListModel
    @EnvironmentObject private var chrome: AppChromeModel
    private let levels: [GeohashChannelLevel] = [.block, .neighborhood, .city, .province, .region]

    private var meshDetail: String {
        switch chrome.bluetoothState {
        case .poweredOn: return "bluetooth"
        case .poweredOff: return "Bluetooth is off"
        case .unauthorized: return "Bluetooth permission needed"
        case .unsupported: return "Bluetooth unavailable on this device"
        default: return "Checking Bluetooth…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EtEyoScreenTitle("locations").padding(.bottom, 12)
            ScrollView {
                LazyVStack(spacing: 0) {
                    Button { open(.mesh) } label: {
                        EtEyoLocationRow(title: "mesh", people: EtEyoLabels.people(peers.reachableMeshPeerCount + 1),
                                         detail: meshDetail, isActive: channels.selectedChannel == .mesh)
                    }
                    .accessibilityIdentifier("eteyo.location.mesh")
                    ForEach(levels, id: \.self) { level in
                        let channel = channels.availableChannels.first { $0.level == level }
                        Button {
                            if let channel { open(.location(channel)) }
                            else { requestLocation() }
                        } label: {
                            EtEyoLocationRow(title: level.eteyoTitle,
                                people: channel.map { EtEyoLabels.people(peers.participantCount(for: $0.geohash), level: level) } ?? "",
                                detail: channel.map { _ in channels.locationName(for: level) ?? "Resolving place name…" } ?? locationStatus,
                                isActive: channel.map { channels.isSelected($0) } ?? false)
                        }
                        .accessibilityIdentifier("eteyo.location.\(level.eteyoTitle)")
                    }
                    if channels.permissionState != .authorized || channels.availableChannels.isEmpty {
                        Button(channels.permissionState == .denied ? "Open location settings" : "Enable location channels", action: requestLocation)
                            .buttonStyle(.bordered).tint(.white).padding(.top, 20)
                            .accessibilityIdentifier("eteyo.enableLocation")
                    }
                }
                .buttonStyle(.plain)
            }
            .scrollIndicators(.hidden)
            .refreshable { channels.refreshChannels() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .onAppear { channels.beginLiveRefresh() }
        .onDisappear { channels.endLiveRefresh() }
        .onChange(of: channels.permissionState) { state in
            if state == .authorized { channels.beginLiveRefresh() }
        }
    }

    private var locationStatus: String {
        switch channels.permissionState {
        case .notDetermined: return "Location permission needed"
        case .denied: return "Location access is off"
        case .restricted: return "Location access is restricted"
        case .authorized: return "Waiting for your location…"
        }
    }

    private func requestLocation() {
        switch channels.permissionState {
        case .denied, .restricted: SystemSettings.location.open()
        case .notDetermined: channels.enableAndRefresh()
        case .authorized: channels.refreshChannels()
        }
    }
}

private struct EtEyoLocationRow: View {
    let title: String
    let people: String
    let detail: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 15)).foregroundStyle(isActive ? Color.accentColor : .primary)
                    .tracking(0.2).frame(minHeight: 18)
                Spacer(minLength: 8)
                Text(people).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1).frame(minHeight: 16)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct EtEyoScreenTitle: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title).font(.system(size: 30, weight: .light)).tracking(0.5)
            .frame(height: 44, alignment: .leading).padding(.horizontal, 20)
    }
}
struct EtEyoEmptyState: View {
    let title: String
    let detail: String
    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(title, systemImage: "bubble.left.and.bubble.right", description: Text(detail))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle)
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(24)
        }
    }
}
#endif
