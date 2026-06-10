import SwiftUI

/// Settings — player-facing app options, opened from the Home gear chip.
///
/// Two sections:
///   ACCESSIBILITY — HIGH LEGIBILITY TEXT (brighter captions + softer white,
///   cuts astigmatism halation) and REDUCE MOTION (drops decorative motion).
///   Both mirror an iOS system setting: when the system switch is on, the
///   in-app toggle shows locked-on rather than lying.
///   SOUND & HAPTICS — GAME SOUND and HAPTICS master switches.
///
/// The ACCESSIBILITY card carries a live SAMPLE so the player sees the
/// legibility change the instant they flip it.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccessibilitySettings.self) private var accessibility
    @Environment(AudioService.self) private var audio

    var body: some View {
        @Bindable var accessibility = accessibility
        @Bindable var audio = audio
        return AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Spacer().frame(height: Spacing.md)

                        accessibilitySection(
                            highLegibility: $accessibility.highLegibilityEnabled,
                            boldText: $accessibility.boldTextEnabled,
                            reduceMotion: $accessibility.reduceMotionEnabled
                        )

                        soundSection(
                            sound: $audio.masterEnabled,
                            haptics: $accessibility.hapticsEnabled
                        )

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

    private func accessibilitySection(
        highLegibility: Binding<Bool>,
        boldText: Binding<Bool>,
        reduceMotion: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("ACCESSIBILITY")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                toggleRow(
                    title: "HIGH LEGIBILITY TEXT",
                    blurb: "Brighter captions and a softer white — cuts the glow that makes grey text on black hard to read.",
                    binding: highLegibility,
                    systemOn: accessibility.systemIncreaseContrast,
                    systemNote: "ON VIA iOS INCREASE CONTRAST"
                )

                divider

                toggleRow(
                    title: "BOLD TEXT",
                    blurb: "Heavier prose and readouts. Display titles already carry full weight.",
                    binding: boldText,
                    systemOn: accessibility.systemBoldText,
                    systemNote: "ON VIA iOS BOLD TEXT"
                )

                divider

                toggleRow(
                    title: "REDUCE MOTION",
                    blurb: "Calms decorative animation — entrance slides, the idle bounce, screen flashes. The physics itself still plays.",
                    binding: reduceMotion,
                    systemOn: accessibility.systemReduceMotion,
                    systemNote: "ON VIA iOS REDUCE MOTION"
                )

                divider

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

    // MARK: - Sound & haptics

    private func soundSection(
        sound: Binding<Bool>,
        haptics: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("SOUND & HAPTICS")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                toggleRow(
                    title: "GAME SOUND",
                    blurb: "Shot results, the bow release, the ball bounce. Every cue also has a visual and a haptic.",
                    binding: sound,
                    systemOn: false,
                    systemNote: ""
                )

                divider

                toggleRow(
                    title: "HAPTICS",
                    blurb: "The taps you feel on a press, a verdict, a release.",
                    binding: haptics,
                    systemOn: false,
                    systemNote: ""
                )
            }
            .padding(Spacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.pillRadius, style: .continuous)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Building blocks

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.sfMono(size: 12))
            .foregroundColor(.arclabMidGrey)
            .tracking(2.0)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.arclabBorderGrey)
            .frame(height: Sizing.borderWidth)
    }

    /// One labeled toggle. When `systemOn` is true the matching iOS setting
    /// already forces the behavior, so the switch reads locked-on (rather
    /// than an off switch that contradicts what the app is doing) and a
    /// note explains why.
    private func toggleRow(
        title: String,
        blurb: String,
        binding: Binding<Bool>,
        systemOn: Bool,
        systemNote: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Toggle(isOn: systemOn ? .constant(true) : binding) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.sfMono(size: 13, weight: .medium))
                        .foregroundColor(.arclabWhite)
                        .tracking(1.5)
                    Text(blurb)
                        .font(.barlowCondensed(size: 15, italic: true))
                        .foregroundColor(.arclabMidGrey)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.arclabRimOrange)
            .disabled(systemOn)

            if systemOn, !systemNote.isEmpty {
                Text(systemNote)
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabRimOrange)
                    .tracking(1.5)
            }
        }
    }

    /// Live specimen of the three text tones the legibility toggle affects.
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
        .environment(AudioService.shared)
}
