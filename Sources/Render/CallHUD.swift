import SwiftUI

/// v2.1 top HUD for the call-first play surface. Quieter than v1's PlayHUDView
/// because the call beat is meant to be predictive — showing distance / hoop
/// height / release height / gravity numbers leaks data the user is supposed
/// to *intuit*. Only a CLOSE affordance + a thin separator rule below.
///
/// `onClose` is optional so the chip can be suppressed during release/finish
/// (no escape mid-flight).
struct CallHUD: View {
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Spacing.sm)

            HStack(alignment: .center, spacing: Spacing.sm) {
                if let onClose {
                    CloseChip(onTap: onClose)
                } else {
                    // Reserve the slot so layout doesn't reflow on toggle.
                    Color.clear.frame(width: 1, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            Rectangle()
                .fill(Color.arclabBorderGrey.opacity(0.5))
                .frame(height: 1)
        }
        .frame(height: 60)
    }
}

private struct CloseChip: View {
    let onTap: () -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button(action: handleTap) {
            Text("✕ CLOSE")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel("Close. Return to home.")
    }

    private func handleTap() {
        tapCount += 1
        onTap()
    }
}
