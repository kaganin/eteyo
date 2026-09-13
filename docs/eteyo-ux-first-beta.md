# eteyo: first beta UX pass

## Direction

A calm, approachable messenger for people who do not know what a geohash,
relay, or slash command is. Keep the eteyo identity, but put familiar actions,
readable conversation content, and predictable behavior first.

Applied skills: `emil-design-eng`, `apple-design`, `context7`, `write-swift`.
Native SwiftUI implements the interaction principles; the web examples in the
design skills are not copied into the iOS application.

## Review and implementation

| Before | After | Why |
| --- | --- | --- |
| Incoming messages always scroll to the bottom | Preserve reading position and offer Latest messages / a new-message count | The reader controls the timeline |
| A slash button is the first composer action | Add menu with Photo and Commands | Common actions are understandable without learning syntax |
| Opening commands replaces the current draft | Browse commands without modifying the draft; protect ordinary text from command replacement | Avoid accidental text loss |
| A fixed subset of commands is suggested | Use the existing context-aware command catalog, plus eteyo's nickname command | Suggest commands that work in the current conversation |
| No mention suggestions | Reuse the runtime's mention suggestions | Make people discoverable while composing |
| Tiny fixed-size message typography | Native body, footnote, and caption text styles | Follow Dynamic Type |
| Similar incoming and outgoing bubbles | Distinct neutral surfaces, sender labels, and date separators | Easier scanning |
| Plain URLs and no message menu | HTTP(S) links, copy, mention, direct message, block | Put actions next to their subject |
| Composer manually reserves a measured height | Native bottom safe-area inset | Keyboard and text-height changes reserve actual space |
| Voice recording shows only a red icon | Visible recording time and Cancel action | Recording has clear ongoing feedback |
| Icon-only tabs | Visible labels alongside existing icons | Improve wayfinding |
| Glass is always translucent | Solid surfaces for Reduce Transparency / Increase Contrast | Respect accessibility preferences |

Messages remain literal text: received Markdown is not interpreted and arbitrary
custom URL schemes are not turned into active links. Mentioning someone inserts
text in the current draft; it is not a quoted-reply protocol feature.

## References actually inspected

- [Messages conversation](https://mobbin.com/screens/e1424a0e-a482-4d6a-8e64-d7641250c57c): plus action beside the composer, left/right bubble hierarchy.
- [X conversation](https://mobbin.com/screens/72b0bed2-1145-48fa-8a7b-0870c593ec54): attachment actions grouped under the plus button, date separation.
- [BeReal conversation](https://mobbin.com/screens/2816e84d-5160-4a6e-a655-716055c41da9): restrained dark conversation surface with bright outgoing content.
- [SwiftUI ScrollViewReader](https://developer.apple.com/documentation/swiftui/scrollviewreader), retrieved through Context7: scroll only from callbacks, not the view builder.
- [SwiftUI safeAreaInset](https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-4s51l), retrieved through Context7: reserve the bottom bar's actual height.

## Verification

- Timeline policy: initial load, incoming arrivals while reading history,
  duplicate updates, returning to latest, outgoing arrivals, deletion and clear.
- Link rendering: preserve literal text and only activate ordinary web URLs.
- Existing eteyo routing/draft and startup-permission regression tests.
- Render the actual conversation with mock transport at standard and accessibility
  text sizes. Fixture messages stay local to the test process.
- Check composer/keyboard, Add/Commands, navigation back and tab labels in Simulator.

## Next beta work

1. Person details: fingerprint/QR verification, favorites, clear block management.
2. Public/private and connectivity explanations, bridge scope controls.
3. Share Extension import, custom location channels and bookmarks.
4. eteyo settings and brand cleanup; privacy/support/reporting flows.
5. Complete localization and accessibility across locations, lists and settings.
6. Real-device delivery/reconnect/background/media tests and a signed archive.

Live push-to-talk, radar/nearby notes, and expanded group management remain
separate work. This pass keeps the existing voice-note transport.
