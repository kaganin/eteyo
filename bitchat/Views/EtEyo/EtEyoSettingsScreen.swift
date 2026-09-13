import SwiftUI

#if os(iOS)
struct EtEyoSettingsScreen: View {
    @EnvironmentObject private var chrome: AppChromeModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var drafts: EtEyoConversationStore
    @EnvironmentObject private var peers: PeerListModel
    @EnvironmentObject private var ui: ConversationUIModel
    @ScaledMetric(relativeTo: .body) private var bodyFontSize = 16
    @State private var nickname = ""
    @State private var hidePreviews = NotificationPrivacySettings.hideMessagePreviews
    @State private var showAdvanced = false
    @State private var showPrivacy = false
    @State private var showBlockedPeople = false
    @State private var showAbout = false

    private var blockedCount: Int {
        peers.meshRows.filter(\.isBlocked).count + peers.geohashPeople.filter(\.isBlocked).count
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title).modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote))
    }

    private var bluetoothStatus: String {
        switch chrome.bluetoothState {
        case .poweredOn: return "Nearby chat ready"
        case .poweredOff: return "Turned off"
        case .unauthorized: return "Permission needed"
        case .unsupported: return "Not supported"
        case .resetting: return "Restarting…"
        default: return "Preparing…"
        }
    }

    private var locationStatus: String {
        switch channels.permissionState {
        case .authorized: return "Location channels ready"
        case .denied: return "Access turned off"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not enabled"
        }
    }

    var body: some View {
        // The tab already lives inside EtEyoRootView’s typed NavigationStack.
        // A nested stack here corrupts SwiftUI’s path comparison after switching tabs.
        VStack(alignment: .leading, spacing: 0) {
            EtEyoScreenTitle("settings")
            Form {
                Section {
                    TextField("Nickname", text: $nickname)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("eteyo.settings.nickname")
                    Button("Save nickname") {
                        chrome.setNickname(nickname)
                        chrome.validateAndSaveNickname()
                        nickname = chrome.nickname
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nickname == chrome.nickname)
                    .accessibilityIdentifier("eteyo.settings.saveNickname")
                } header: { sectionHeader("Profile") }
                Section {
                    Button { SystemSettings.bluetooth.open() } label: {
                        LabeledContent("Bluetooth", value: bluetoothStatus)
                    }
                    Button {
                        if channels.permissionState == .notDetermined { channels.enableAndRefresh() }
                        else { SystemSettings.location.open() }
                    } label: { LabeledContent("Location access", value: locationStatus) }
                    Toggle("Use Tor", isOn: Binding(get: { channels.userTorEnabled }, set: { channels.setUserTorEnabled($0) }))
                    if chrome.torBlocked {
                        Text("Tor is having trouble connecting.").font(.footnote)
                            .modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote)).foregroundStyle(.secondary)
                    }
                } header: { sectionHeader("Connectivity") } footer: {
                    Text("Bluetooth powers nearby chat. Location access finds public channels around you. Tor protects online delivery.")
                        .modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote))
                }
                Section {
                    Toggle("Hide message previews", isOn: $hidePreviews)
                        .accessibilityIdentifier("eteyo.settings.hidePreviews")
                    Button { showBlockedPeople = true } label: {
                        LabeledContent("Blocked people", value: blockedCount.formatted())
                    }
                    Button("How eteyo protects your privacy") { showPrivacy = true }
                } header: { sectionHeader("Privacy") } footer: {
                    Text("Keep message text and sender names out of notifications.")
                        .modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote))
                }
                Section {
                    Link("Help and report a problem", destination: URL(string: "https://github.com/kaganin/eteyo/issues")!)
                    Button("About eteyo") { showAbout = true }
                    Button("Advanced diagnostics") { showAdvanced = true }
                        .accessibilityIdentifier("eteyo.settings.advanced")
                } header: { sectionHeader("Help and about") }
            }
            .font(.system(size: bodyFontSize))
            .modifier(EtEyoNativeTracking(size: 16, relativeTo: .body))
            .scrollContentBackground(.hidden)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.white)
        .onAppear {
            nickname = chrome.nickname
            hidePreviews = NotificationPrivacySettings.hideMessagePreviews
        }
        .onChange(of: hidePreviews) { NotificationPrivacySettings.hideMessagePreviews = $0 }
        .sheet(isPresented: $showAdvanced) {
            AppInfoView(topologyProvider: { chrome.meshTopologyDisplayModel() }, onPanicWipe: {
                drafts.clear()
                showAdvanced = false
                chrome.panicClearAllData()
            })
        }
        .sheet(isPresented: $showPrivacy) { EtEyoPrivacyScreen() }
        .sheet(isPresented: $showAbout) { EtEyoAboutScreen() }
        .sheet(isPresented: $showBlockedPeople) {
            EtEyoBlockedPeopleScreen(
                meshRows: peers.meshRows.filter(\.isBlocked),
                geohashRows: peers.geohashPeople.filter(\.isBlocked),
                unblockMesh: { ui.unblock(peerID: $0.peerID, displayName: $0.displayName) },
                unblockGeohash: { peers.unblockGeohashUser(pubkeyHexLowercased: $0.id, displayName: $0.displayName) }
            )
        }
    }
}

private struct EtEyoPrivacyScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages stay on your device").font(.headline)
                        Text("Chat history is temporary and is not stored in an eteyo account.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "iphone") }
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Private chats are encrypted").font(.headline)
                        Text("Verify a contact in person when identity matters.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "lock.shield") }
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location channels are public").font(.headline)
                        Text("A place code describes an area. Anyone in that channel can read public messages.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "location") }
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nearby devices can detect activity").font(.headline)
                        Text("Bluetooth mesh reveals that an eteyo-compatible app is active to devices in radio range.").font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "antenna.radiowaves.left.and.right") }
            }
            .navigationTitle("Your privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

private struct EtEyoAboutScreen: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("eteyo").font(.largeTitle.weight(.light))
                        Text("Private conversations nearby and around the world, powered by open protocols.")
                            .font(.body).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    LabeledContent("Version", value: version)
                }
                Section("Open source") {
                    Link("View eteyo on GitHub", destination: URL(string: "https://github.com/kaganin/eteyo")!)
                    Link("Built on bitchat", destination: URL(string: "https://github.com/permissionlesstech/bitchat")!)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

private struct EtEyoBlockedPeopleScreen: View {
    let meshRows: [MeshPeerRow]
    let geohashRows: [GeohashPersonRow]
    let unblockMesh: (MeshPeerRow) -> Void
    let unblockGeohash: (GeohashPersonRow) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if meshRows.isEmpty && geohashRows.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark").font(.largeTitle)
                        Text("No blocked people").font(.headline)
                        Text("People you block will appear here.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                ForEach(meshRows) { row in
                    blockedRow(name: row.displayName) { unblockMesh(row) }
                }
                ForEach(geohashRows) { row in
                    blockedRow(name: row.displayName) { unblockGeohash(row) }
                }
            }
            .navigationTitle("Blocked people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func blockedRow(name: String, unblock: @escaping () -> Void) -> some View {
        HStack {
            Text(name)
            Spacer()
            Button("Unblock", action: unblock).buttonStyle(.bordered)
        }
    }
}
#endif
