#if os(iOS)
import CoreBluetooth
import Testing
@testable import bitchat

struct EtEyoStartupPermissionsTests {
    @Test func waitsUntilTheAppIsActiveAndBluetoothHasAnAnswer() {
        var flow = EtEyoStartupPermissions()
        let request1 = flow.takeLocationRequest(isActive: false, bluetoothAuthorization: .allowedAlways,
            bluetoothState: .poweredOn, locationPermission: .notDetermined)
        #expect(!request1)
        let request2 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .notDetermined,
            bluetoothState: .unknown, locationPermission: .notDetermined)
        #expect(!request2)
        let request3 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .allowedAlways,
            bluetoothState: .poweredOn, locationPermission: .notDetermined)
        #expect(request3)
    }

    @Test func bluetoothDenialDoesNotBlockLocationChannels() {
        var flow = EtEyoStartupPermissions()
        let request4 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .denied,
            bluetoothState: .unauthorized, locationPermission: .notDetermined)
        #expect(request4)
    }

    @Test func simulatorDoesNotWaitForAnUnsupportedBluetoothPrompt() {
        var flow = EtEyoStartupPermissions()
        let request5 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .notDetermined,
            bluetoothState: .unsupported, locationPermission: .notDetermined)
        #expect(request5)
    }

    @Test func deniedAndRestrictedLocationAreNotRequestedAgain() {
        var flow = EtEyoStartupPermissions()
        for permission in [LocationChannelManager.PermissionState.denied, .restricted] {
            let request6 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .allowedAlways,
                bluetoothState: .poweredOn, locationPermission: permission)
            #expect(!request6)
        }
    }

    @Test func authorizedLocationRefreshesOnlyOnceAcrossForegroundTransitions() {
        var flow = EtEyoStartupPermissions()
        let request7 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .allowedAlways,
            bluetoothState: .poweredOn, locationPermission: .authorized)
        #expect(request7)
        let request8 = flow.takeLocationRequest(isActive: false, bluetoothAuthorization: .allowedAlways,
            bluetoothState: .poweredOn, locationPermission: .authorized)
        #expect(!request8)
        let request9 = flow.takeLocationRequest(isActive: true, bluetoothAuthorization: .allowedAlways,
            bluetoothState: .poweredOn, locationPermission: .authorized)
        #expect(!request9)
    }
}
#endif
