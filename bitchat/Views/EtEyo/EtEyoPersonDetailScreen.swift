import SwiftUI

#if os(iOS)
struct EtEyoPersonDetailScreen: View {
    let state: PrivateConversationHeaderState
    let isBlocked: Bool
    let onBlock: () -> Void
    let onUnblock: () -> Void

    @EnvironmentObject private var privateChat: PrivateConversationModel
    @EnvironmentObject private var verification: VerificationModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSecurityDetails = false
    @State private var showScanner = false
    @State private var confirmBlock = false

    private var fingerprint: FingerprintPresentationState {
        verification.fingerprintPresentation(for: state.headerPeerID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identityCard
                    connectionCard
                    if !state.conversationPeerID.isGeoDM { trustCard }
                    actionsCard
                }
                .padding(16)
            }
            .background(Color.black)
            .navigationTitle("Contact details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $showSecurityDetails) {
            FingerprintView(peerID: state.headerPeerID)
                .environmentObject(verification)
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScanView(isActive: showScanner) { showScanner = false }
                    .navigationTitle("Scan verification QR")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showScanner = false }
                        }
                    }
            }
            .environmentObject(verification)
            .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            "Block \(state.displayName)?",
            isPresented: $confirmBlock,
            titleVisibility: .visible
        ) {
            Button("Block person", role: .destructive) {
                onBlock()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will stop receiving messages from this person. You can unblock them later in Settings.")
        }
    }

    private var identityCard: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 72, height: 72)
                .overlay {
                    Text(state.displayName.prefix(1).uppercased())
                        .font(.largeTitle.weight(.semibold))
                }
            HStack(spacing: 6) {
                Text(state.displayName)
                    .font(.title2.weight(.semibold))
                if fingerprint.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Verified contact")
                }
            }
            Text(fingerprint.isVerified ? "Identity verified on this device" : "Identity not verified yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .eteyoDetailCard()
    }

    private var connectionCard: some View {
        EtEyoDetailRow(
            icon: connectionIcon,
            title: connectionTitle,
            detail: connectionDetail,
            tint: connectionTint
        )
        .padding(16)
        .eteyoDetailCard()
    }

    private var trustCard: some View {
        VStack(spacing: 0) {
            Button {
                showSecurityDetails = true
            } label: {
                EtEyoDetailRow(
                    icon: fingerprint.isVerified ? "checkmark.shield.fill" : "lock.shield",
                    title: "Identity and encryption",
                    detail: fingerprint.isVerified ? "Verified" : "Compare security codes",
                    tint: fingerprint.isVerified ? .green : .white,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 48)

            Button { showScanner = true } label: {
                EtEyoDetailRow(
                    icon: "qrcode.viewfinder",
                    title: "Scan verification QR",
                    detail: "Verify in person",
                    tint: .white,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .eteyoDetailCard()
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            if state.supportsFavoriteToggle {
                Button {
                    privateChat.toggleFavorite(peerID: state.headerPeerID)
                } label: {
                    EtEyoDetailRow(
                        icon: state.isFavorite ? "star.fill" : "star",
                        title: state.isFavorite ? "Remove from favorites" : "Add to favorites",
                        detail: "Keep this person easy to find",
                        tint: state.isFavorite ? .yellow : .white
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 48)
            }

            Button {
                if isBlocked { onUnblock() } else { confirmBlock = true }
            } label: {
                EtEyoDetailRow(
                    icon: isBlocked ? "person.crop.circle.badge.checkmark" : "hand.raised.fill",
                    title: isBlocked ? "Unblock person" : "Block person",
                    detail: isBlocked ? "Allow messages again" : "Stop messages from this person",
                    tint: isBlocked ? .white : .red
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .eteyoDetailCard()
    }

    private var connectionIcon: String {
        switch state.availability {
        case .bluetoothConnected: "dot.radiowaves.left.and.right"
        case .meshReachable: "point.3.connected.trianglepath.dotted"
        case .nostrAvailable: "globe"
        case .offline: "circle.slash"
        }
    }

    private var connectionTitle: LocalizedStringKey {
        switch state.availability {
        case .bluetoothConnected: "Nearby now"
        case .meshReachable: "Reachable nearby"
        case .nostrAvailable: "Reachable online"
        case .offline: "Currently offline"
        }
    }

    private var connectionDetail: LocalizedStringKey {
        switch state.availability {
        case .bluetoothConnected: "Connected directly over Bluetooth"
        case .meshReachable: "Messages can travel through nearby devices"
        case .nostrAvailable: "Messages can be delivered over the internet"
        case .offline: "Messages will wait until a route is available"
        }
    }

    private var connectionTint: Color {
        state.availability == .offline ? .secondary : .green
    }
}

private struct EtEyoDetailRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let tint: Color
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

private extension View {
    func eteyoDetailCard() -> some View {
        background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
