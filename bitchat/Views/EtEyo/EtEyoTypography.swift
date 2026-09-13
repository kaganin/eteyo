import SwiftUI

#if os(iOS)
/// Shared typography rule: 15 pt text uses 0.2 pt of additional tracking.
/// Keep native font line heights; layout spacing belongs to the surrounding views.
enum EtEyoTypography {
    static func tracking(for size: CGFloat) -> CGFloat { size * (0.2 / 15) }
}

/// Adds proportional tracking without overriding a native control's font or Dynamic Type.
struct EtEyoNativeTracking: ViewModifier {
    @ScaledMetric private var size: CGFloat

    init(size: CGFloat, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.tracking(EtEyoTypography.tracking(for: size))
    }
}
#endif
