import SwiftUI

/// Settings — player-facing app options, opened from the Home gear chip.
///
/// v1 ships the ACCESSIBILITY section. The HIGH LEGIBILITY TEXT toggle came
/// from player feedback: mid-grey captions next to white type on the black
/// background are hard to read with astigmatism (bright-on-dark halation).
/// Flipping it swaps the text tokens app-wide (see `Color+Tokens.swift`):
/// brighter mid-grey (#B4B4B4, ~10:1), softened white (#E6E6E6), and more
/// visible borders. iOS "Increase Contrast" activates the same palette
/// automatically — when it's on, the toggle shows as locked-on.
///
/// The SAMPLE block renders all three text tones live, so the player sees
/// what the switch does the instant they flip it.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccessibilitySettings.self) private var accessibility

    var body: some View {
        @Bindable var accessibility = accessibility
        return AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Spacer().frame(height: Spacing.md)

                        accessibilitySection(toggle: $accessibility.highLegibilityEnabled)

                        Spacer().frame(height: Spacing.xxl)
                    }
                    .padding(.top, Spacing.sm)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: "Home", action: { dismiss() }),
            trailing: .label("SETTINGS")
        )
    }

    // MARK: - Accessibility

    private func accessibilitySection(toggle: Binding<Bool>) -> some View {
        let systemOn = accessibility.systemIncreaseContrast
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("ACCESSIBILITY")
                .font(.sfMono(size: 12))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                // System Increase Contrast wins: the palette is active no
                // matter what, so show the switch locked-on instead of an
                // off switch that's lying.
                Toggle(isOn: systemOn ? .constant(true) : toggle) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("HIGH LEGIBILITY TEXT")
                            .font(.sfMono(size: 13, weight: .medium))
                            .foregroundColor(.arclabWhite)
                            .tracking(1.5)
                        Text("Brighter captions and a softer white — cuts the glow that makes grey text on black hard to read.")
                            .font(.barlowCondensed(size: 15, italic: true))
                            .foregroundColor(.arclabMidGrey)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(.arclabRimOrange)
                .disabled(systemOn)

                if systemOn {
                    Text("ON VIA iOS INCREASE CONTRAST")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabRimOrange)
                        .tracking(1.5)
                }

                Rectangle()
                    .fill(Color.arclabBorderGrey)
                    .frame(height: Sizing.borderWidth)

                sample
            }
            .padding(Spacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.pillRadius, style: .continuous)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )

            Text("Phisios also follows your iOS settings: Increase Contrast, Bold Text, and Larger Text (Settings → Accessibility → Display & Text Size).")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Live specimen of the three text tones the toggle affects.
    private var sample: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("SAMPLE")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
            Text("PROJECTILE MOTION")
                .font(.anton(size: 24))
                .foregroundColor(.arclabWhite)
            Text("Every arc a ball traces is a parabola — gravity bends each flight the same way.")
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample text showing the current legibility setting.")
    }
}

#Preview {
    SettingsView()
        .environment(AccessibilitySettings.shared)
}
