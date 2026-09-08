import SwiftUI

#if os(iOS)
/// The eteyo layered composer: the drawer moves while the input stays in front.
struct EtEyoChatComposer: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool
    var canSend = true
    var canAttach = true
    let send: () -> Void
    let attach: () -> Void
    let heightChanged: (CGFloat) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inputHeight: CGFloat = 44

    private let commands = [
        EtEyoCommand(alias: "/help", description: "show available commands"),
        EtEyoCommand(alias: "/nick", argument: "nickname", description: "change your nickname"),
        EtEyoCommand(alias: "/block", argument: "@nickname", description: "block or list blocked peers"),
        EtEyoCommand(alias: "/unblock", argument: "@nickname", description: "unblock a peer"),
        EtEyoCommand(alias: "/clear", description: "clear chat messages"),
        EtEyoCommand(alias: "/hug", description: "send someone a warm hug"),
        EtEyoCommand(alias: "/slap", description: "slap someone with a trout"),
        EtEyoCommand(alias: "/msg", description: "send private message"),
        EtEyoCommand(alias: "/who", description: "see who’s online")
    ]
    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var showsCommands: Bool { text.hasPrefix("/") && !text.contains(where: { $0.isWhitespace }) }
    private var motion: Animation { reduceMotion ? .easeOut(duration: 0.2) : .interactiveSpring(response: 0.28, dampingFraction: 0.9) }
    private var matchingCommands: [EtEyoCommand] {
        let query = text.lowercased()
        return commands.filter { $0.alias.hasPrefix(query) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showsCommands {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if matchingCommands.isEmpty {
                            Text("No matching commands")
                                .foregroundStyle(.secondary)
                                .padding(16)
                        }
                        ForEach(matchingCommands) { item in
                            Button {
                                text = item.alias + " "
                                focused = true
                            } label: {
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Text(item.alias)
                                            .foregroundStyle(.white)

                                        if let argument = item.argument {
                                            Text(argument)
                                                .foregroundStyle(.white.opacity(0.65))
                                        }
                                    }
                                    .font(.system(size: 15, weight: .regular))

                                    Spacer(minLength: 12)

                                    Text(item.description)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 42)
                                    .padding(.horizontal, 20)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, inputHeight + 12)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 300 + inputHeight)
                .background(Color(white: 0.1), in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
                .transition(reduceMotion ? .opacity : .modifier(
                    active: EtEyoDrawerTransition(progress: 0),
                    identity: EtEyoDrawerTransition(progress: 1)
                ))
                .zIndex(0)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: openCommands) {
                    Text("/")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .modifier(EtEyoGlassSurface(radius: 22, interactive: true))
                .accessibilityLabel("Commands")
                .accessibilityHint("Shows available slash commands")

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        TextField("Message", text: $text, axis: .vertical)
                            .font(.system(size: 17))
                            .textFieldStyle(.plain)
                            .lineLimit(1...5)
                            .focused($focused)
                            .padding(.leading, 16)
                            .padding(.vertical, 11)
                            .accessibilityIdentifier("eteyo.message")

                        Button(action: attach) {
                            Image("EtEyo-attach")
                                .renderingMode(.template)
                                .foregroundStyle(.white.opacity(0.65))
                                .frame(width: 42, height: 36)
                        }
                        .disabled(!canAttach)
                        .accessibilityLabel("Attach")
                        .padding(.leading, 6)
                        .padding(.bottom, 4)

                        if hasText {
                            Button(action: send) {
                                Image("EtEyo-send")
                                    .renderingMode(.template)
                                    .foregroundStyle(.black)
                                    .frame(width: 42, height: 36)
                                    .background(.white, in: Capsule())
                            }
                            .disabled(!canSend)
                            .accessibilityLabel("Send message")
                            .accessibilityIdentifier("eteyo.send")
                            .padding(.bottom, 4)
                            .transition(.opacity)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .modifier(EtEyoGlassSurface(radius: 22, interactive: true))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { measure(proxy.size.height) }
                        .onChange(of: proxy.size.height) { measure($0) }
                }
            }
            .zIndex(2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(motion, value: focused)
        .animation(motion, value: hasText)
        .animation(motion, value: showsCommands)
    }

    private func measure(_ height: CGFloat) {
        inputHeight = height
        heightChanged(height + 12)
    }

    private func openCommands() {
        text = "/"
        focused = true
    }
}

private struct EtEyoCommand: Identifiable {
    let alias: String
    var argument: String?
    let description: String

    var id: String { alias }
}

struct EtEyoGlassSurface: ViewModifier {
    let radius: CGFloat
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(interactive), in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.1), lineWidth: 0.5))
        }
    }
}

private struct EtEyoDrawerTransition: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .hidden()
            .overlay {
                GeometryReader { proxy in
                    content.offset(y: proxy.size.height * (1 - progress))
                }
            }
            .clipped()
    }
}
#endif
