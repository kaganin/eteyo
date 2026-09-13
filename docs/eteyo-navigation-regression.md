# eteyo navigation regression check

The root owns a typed `NavigationStack<[EtEyoConversation]>` around the tabs.
Settings must not introduce another stack into that hierarchy. Independently
presented sheets can own their own navigation stacks.

## Reproduction (2026-09-09)

1. Launch the app and visit Settings.
2. Return to Locations.
3. Open Region.

Before the fix, this sequence crashed on the iOS 26.5 simulator. The connected
iPhone Air running iOS 26.5.2 was paused in Xcode on the same fatal error:
`SwiftUI.AnyNavigationPath.Error.comparisonTypeMismatch` in
`SwiftUI/NavigationColumnState.swift`. A debugger-attached crash looked like a
frozen screen on the phone.

The fix removes Settings' nested NavigationStack and uses the root stack.
After the fix, the same simulator sequence opens the Region conversation.
Both simulator and signed device Debug builds succeed.

Repeat the sequence when changing tab/navigation structure. Also verify back
navigation, opening other location cells, and presenting/dismissing Settings'
More settings sheet. Device interaction still needs confirmation after install.
