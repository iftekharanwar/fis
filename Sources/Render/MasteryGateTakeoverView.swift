import SwiftUI

/// v3 §3.2–§3.5 — the between-level-type takeover screens. Fires when
/// the player clears mastery on Level Type N. Brief, declarative,
/// always ends with a TAP chip that advances to the picker.
struct MasteryGateTakeoverView: View {
    let headline: String         // e.g. "FOUND THE LIFT."
    let bodyLines: [String]      // 2–3 lines, declarative
    let onTap: () -> Void

    @State private var tapCount: Int = 0
    @State private var appearHapticCount: Int = 0

    var body: some View {
        ZStack {
            Color.arclabBlack.ignoresSafeArea()

            AdaptiveContentContainer(maxWidth: 600) {
                VStack(spacing: Spacing.xl) {
                    Spacer()

                    Text(headline)
                        .font(.anton(size: 48))
                        .foregroundColor(.arclabWhite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)

                    VStack(spacing: Spacing.xs) {
                        ForEach(Array(bodyLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.barlowCondensed(size: 18, italic: true))
                                .foregroundColor(.arclabMidGrey)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer()

                    Text("▾ TAP")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)

                    Spacer().frame(height: Spacing.xxl)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tapCount += 1
            onTap()
        }
        .gameHaptic(.impact(weight: .medium), trigger: tapCount)
        // Mastery moment celebration: fires on first appear when the takeover
        // lands. .success is the same haptic the system uses for completing
        // a tracked workout — perfect for "you just cleared the level type."
        .gameHaptic(.success, trigger: appearHapticCount)
        .onAppear { appearHapticCount += 1 }
        .statusBarHidden(true)
        // The whole takeover advances on tap — expose it as one labeled
        // button so VoiceOver/Switch Control users aren't stranded.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline) \(bodyLines.joined(separator: " "))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to continue.")
        .accessibilityAction {
            tapCount += 1
            onTap()
        }
    }

    /// The 4 v3 mastery-gate takeovers, keyed by which level type was just cleared.
    /// Per locked spec §3.2 (after A), §3.3 (after B), §3.4 (after C), §3.5 (after D).
    static func config(after clearedLevelType: LevelTypeID) -> (headline: String, body: [String]) {
        switch clearedLevelType {
        case .findTheta:
            return (
                "FOUND THE LIFT.",
                ["Speed is next.",
                 "Same equation.",
                 "Different unknown."]
            )
        case .findV:
            return (
                "FOUND THE SPEED.",
                ["Distance is next.",
                 "Same equation.",
                 "Different unknown."]
            )
        case .findD:
            return (
                "PICKED THE SPOT.",
                ["Two unknowns is next.",
                 "Same equation.",
                 "Both at once."]
            )
        case .findBoth:
            return (
                "LOCKED THE ARC.",
                ["The shape is yours now.",
                 "Chapter 2 is the spin."]
            )
        case .findG:
            return (
                "FOUND GRAVITY.",
                ["The constant was a variable all along."]
            )
        }
    }
}
