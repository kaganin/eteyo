import CoreBluetooth
import SwiftUI

#if os(iOS)
struct EtEyoConnectionNotice: View {
    let bluetoothState: CBManagerState
    let locationState: LocationChannelManager.PermissionState
    let torBlocked: Bool
    let openBluetoothSettings: () -> Void
    let openLocationSettings: () -> Void

    var body: some View {
        if let notice {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notice.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(notice.tint)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title).font(.subheadline.weight(.semibold))
                    Text(notice.detail).font(.footnote).foregroundStyle(.secondary)
                    if let actionTitle = notice.actionTitle {
                        Button(actionTitle, action: notice.action)
                            .font(.footnote.weight(.semibold))
                            .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("eteyo.connectionNotice")
        }
    }

    private var notice: Notice? {
        switch bluetoothState {
        case .poweredOff:
            return Notice(
                icon: "antenna.radiowaves.left.and.right.slash",
                title: "Nearby chat is paused",
                detail: "Turn on Bluetooth to find and message people nearby.",
                tint: .orange,
                actionTitle: "Open Bluetooth Settings",
                action: openBluetoothSettings
            )
        case .unauthorized:
            return Notice(
                icon: "lock.fill",
                title: "Bluetooth permission is needed",
                detail: "Allow Bluetooth to use nearby chat. Location is not shared with other people.",
                tint: .orange,
                actionTitle: "Open Settings",
                action: openBluetoothSettings
            )
        case .unsupported:
            return Notice(
                icon: "iphone.slash",
                title: "Nearby chat is unavailable",
                detail: "This device cannot use Bluetooth mesh. Location channels can still work online.",
                tint: .secondary,
                actionTitle: nil,
                action: {}
            )
        default:
            break
        }

        switch locationState {
        case .denied:
            return Notice(
                icon: "location.slash.fill",
                title: "Location channels are paused",
                detail: "Allow location access to discover public conversations around you.",
                tint: .orange,
                actionTitle: "Open Location Settings",
                action: openLocationSettings
            )
        case .restricted:
            return Notice(
                icon: "location.slash.fill",
                title: "Location access is restricted",
                detail: "Location channels are unavailable under the device's current restrictions.",
                tint: .secondary,
                actionTitle: nil,
                action: {}
            )
        default:
            break
        }

        if torBlocked {
            return Notice(
                icon: "network.slash",
                title: "Private internet connection is delayed",
                detail: "Nearby chat still works. Online delivery will resume when Tor connects.",
                tint: .orange,
                actionTitle: nil,
                action: {}
            )
        }
        return nil
    }

    private struct Notice {
        let icon: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let tint: Color
        let actionTitle: LocalizedStringKey?
        let action: () -> Void
    }
}
#endif
