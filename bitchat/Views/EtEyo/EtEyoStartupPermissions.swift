#if os(iOS)
import CoreBluetooth

/// BLE startup already requests system authorization through the existing transport.
/// Wait for that decision before asking Core Location, so prompts do not overlap.
struct EtEyoStartupPermissions {
    private var didRequestLocation = false

    mutating func takeLocationRequest(
        isActive: Bool,
        bluetoothAuthorization: CBManagerAuthorization,
        bluetoothState: CBManagerState,
        locationPermission: LocationChannelManager.PermissionState
    ) -> Bool {
        guard isActive, !didRequestLocation else { return false }
        // The Simulator reports unsupported and never presents a Bluetooth prompt.
        guard bluetoothState == .unsupported || bluetoothAuthorization != .notDetermined else { return false }
        guard locationPermission == .notDetermined || locationPermission == .authorized else { return false }
        didRequestLocation = true
        return true
    }
}
#endif
