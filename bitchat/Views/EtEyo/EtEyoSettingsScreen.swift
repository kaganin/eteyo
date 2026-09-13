import SwiftUI

#if os(iOS)
struct EtEyoSettingsScreen: View {
    @EnvironmentObject private var chrome: AppChromeModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var drafts: EtEyoConversationStore
    @ScaledMetric(relativeTo: .body) private var bodyFontSize = 16
    @State private var nickname = ""
    @State private var hidePreviews = NotificationPrivacySettings.hideMessagePreviews
    @State private var showAdvanced = false

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title).modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote))
    }

    private var bluetoothStatus: String {
        switch chrome.bluetoothState {
        case .poweredOn: return "On"
        case .poweredOff: return "Off"
        case .unauthorized: return "Permission needed"
        case .unsupported: return "Unavailable"
        case .resetting: return "Restarting…"
        default: return "Checking…"
        }
    }

    private var locationStatus: String {
        switch channels.permissionState {
        case .authorized: return "Allowed"
        case .denied: return "Not allowed"
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
                } header: { sectionHeader("Connectivity") }
                Section {
                    Toggle("Hide message previews", isOn: $hidePreviews)
                        .accessibilityIdentifier("eteyo.settings.hidePreviews")
                } header: { sectionHeader("Privacy") } footer: {
                    Text("Keep message text and sender names out of notifications.")
                        .modifier(EtEyoNativeTracking(size: 13, relativeTo: .footnote))
                }
                Section {
                    Button("More settings and app information") { showAdvanced = true }
                        .accessibilityIdentifier("eteyo.settings.advanced")
                    Link("Powered by bitchat", destination: URL(string: "https://github.com/permissionlesstech/bitchat")!)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                } header: { sectionHeader("eteyo") }
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
    }
}
#endif
