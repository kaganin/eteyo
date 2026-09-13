import SwiftUI

#if os(iOS)
/// Familiar message entry first; slash commands remain available through Add.
struct EtEyoChatComposer: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var canSend = true
    var canAttach = true
    let send: () -> Void
    let attach: () -> Void
    let sendVoiceNote: (URL) -> Void

    @EnvironmentObject private var ui: ConversationUIModel
    @EnvironmentObject private var channels: LocationChannelsModel
    @EnvironmentObject private var privateChat: PrivateConversationModel
    @StateObject private var voiceRecording = VoiceRecordingViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var browsingCommands = false

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var showsCommands: Bool {
        focused && (browsingCommands || (text.hasPrefix("/") && !text.contains(where: { $0.isWhitespace })))
    }
    private var commands: [EtEyoCommand] {
        let peer = privateChat.selectedPeerID
        let available = CommandInfo.all(
            isGeoPublic: peer == nil && channels.selectedChannel.isLocation,
            isGeoDM: peer?.isGeoDM == true || peer?.isGeoChat == true
        ).map { EtEyoCommand(alias: $0.alias, description: $0.description) }
        return [EtEyoCommand(alias: "/nick", description: String(localized: "Change your nickname"))] + available
    }
    private var matchingCommands: [EtEyoCommand] {
        browsingCommands ? commands : commands.filter { $0.alias.hasPrefix(text.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 10) {
            if showsCommands {
                suggestions
            } else if focused && ui.showAutocomplete {
                mentionSuggestions
            }
            if voiceRecording.state.isActive {
                recordingStatus
            }
            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button("Photo", systemImage: "photo") { attach() }
                        .disabled(!canAttach)
                    Button("Commands", systemImage: "slash.circle") {
                        browsingCommands = true
                        focused = true
                    }
                    .disabled(hasText && !text.hasPrefix("/"))
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .medium))
                        .frame(width: 44, height: 44)
                        .modifier(EtEyoGlassSurface(radius: 22, interactive: true))
                }
                .accessibilityLabel("Add to message")
                .accessibilityIdentifier("eteyo.add")

                TextField("Message", text: $text, axis: .vertical)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .modifier(EtEyoGlassSurface(radius: 22, interactive: true))
                    .accessibilityIdentifier("eteyo.message")

                trailingAction
            }
        }
        .buttonStyle(EtEyoPressStyle())
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.96))
        .onChange(of: text) { value in
            browsingCommands = false
            ui.updateAutocomplete(for: value, cursorPosition: value.count)
        }
        .onChange(of: focused) { value in
            if !value { browsingCommands = false; ui.dismissAutocomplete() }
        }
        .onDisappear { voiceRecording.cancel(); ui.dismissAutocomplete() }
        .onChange(of: scenePhase) { if $0 != .active { voiceRecording.cancel() } }
        .onChange(of: canAttach) { if !$0 { voiceRecording.cancel() } }
        .onChange(of: hasText) { if $0 { voiceRecording.cancel() } }
        .alert("Voice recording", isPresented: $voiceRecording.showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(voiceRecording.state.alertMessage) }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Commands").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    browsingCommands = false
                    focused = false
                } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Close commands")
            }.padding(.leading, 16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if matchingCommands.isEmpty {
                        Text("No matching commands").font(.subheadline).foregroundStyle(.secondary).padding(16)
                    }
                    ForEach(matchingCommands) { command in
                        Button {
                            text = command.alias + " "
                            browsingCommands = false
                            focused = true
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(command.alias).font(.subheadline.weight(.semibold))
                                Text(command.description).font(.footnote).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }.frame(maxHeight: 220)
        }
        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 20))
    }

    private var mentionSuggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ui.autocompleteSuggestions.prefix(4)), id: \.self) { nickname in
                    Button {
                        var updated = text
                        _ = ui.completeNickname(nickname, in: &updated)
                        text = updated
                        focused = true
                    } label: {
                        Text(nickname).font(.body)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 16).contentShape(Rectangle())
                    }
                }
            }
        }
        .frame(maxHeight: 176)
        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 20))
    }

    private var recordingStatus: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 7, height: 7).accessibilityHidden(true)
            Text("Recording").font(.subheadline)
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                Text(voiceRecording.formattedDuration(for: context.date))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            Button("Cancel") { voiceRecording.cancel() }.font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
                .accessibilityIdentifier("eteyo.cancelRecording")
        }.padding(.horizontal, 6)
    }

    @ViewBuilder private var trailingAction: some View {
        if hasText {
            Button(action: send) {
                Image("EtEyo-send").renderingMode(.template)
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.4)
            .accessibilityLabel("Send message")
            .accessibilityIdentifier("eteyo.send")
        } else {
            Group {
                if voiceRecording.state.isActive {
                    Image(systemName: "waveform").font(.system(size: 20))
                } else {
                    Image("EtEyo-mic").renderingMode(.template)
                }
            }
            .foregroundStyle(voiceRecording.state.isActive ? .red : .white)
            .frame(width: 44, height: 44)
            .modifier(EtEyoGlassSurface(radius: 22, interactive: true))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in voiceRecording.start(shouldShow: canAttach) }
                    .onEnded { _ in voiceRecording.finish(completion: sendVoiceNote) }
            )
            .allowsHitTesting(canAttach)
            .opacity(canAttach ? 1 : 0.4)
            .accessibilityLabel("Record voice message")
            .accessibilityValue(voiceRecording.state.isActive ? "Recording" : "")
            .accessibilityHint("Hold to record, release to send. Double-tap with VoiceOver to start or stop.")
            .accessibilityIdentifier("eteyo.microphone")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if voiceRecording.state.isActive { voiceRecording.finish(completion: sendVoiceNote) }
                else { voiceRecording.start(shouldShow: canAttach) }
            }
        }
    }
}

private struct EtEyoCommand: Identifiable {
    let alias: String
    let description: String
    var id: String { alias }
}

struct EtEyoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct EtEyoGlassSurface: ViewModifier {
    let radius: CGFloat
    var interactive = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.4), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(interactive), in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.1), lineWidth: 0.5))
        }
    }
}
#endif
