import SwiftUI

/// Post-attempt MISSED screen.
struct MissedView: View {
    let scenario: ScenarioDefinition
    let category: String        // "SHORT" | "FRONT_RIM" | "BACK_RIM" | "OVERSHOOT" | "AIRBALL"
    let attempt: Int            // 1-indexed
    let onTryAgain: () -> Void
    let onSolution: () -> Void

    var body: some View {
        ZStack {
            backgroundTint.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Spacing.lg)
                topRow
                Spacer().frame(height: Spacing.sm)
                verb
                Spacer().frame(height: Spacing.md)
                rule
                Spacer().frame(height: Spacing.sm)
                subhead
                if let diag = diagnosticLine {
                    Spacer().frame(height: Spacing.md)
                    Text(diag)
                        .font(.barlowCondensed(size: 14, italic: true))
                        .foregroundColor(.arclabMidGrey)
                }
                Spacer()
                buttonRow
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .announceOnAppear {
            let variants = scenario.outcome.missCategories.first(where: { $0.id == category })?.subheadVariants ?? [:]
            let key: String = attempt >= 3 ? "3+" : "\(attempt)"
            let subhead = variants[key] ?? variants["1"] ?? category
            return "\(scenario.voice.miss.headline). \(category), attempt \(attempt). \(subhead) "
                + "\(diagnosticLine.map { "\($0) " } ?? "")"
                + "Buttons below: \(scenario.voice.miss.retryLabel)"
                + "\(isSolutionUnlocked ? ", and \(scenario.voice.solutionLabel)." : ".")"
        }
    }

    private var backgroundTint: Color {
        let hex = category == "AIRBALL"
            ? scenario.animations.outcome.miss.tintBackgroundHexAirball ?? "#0C0404"
            : scenario.animations.outcome.miss.tintBackgroundHex
        return Color(hexString: hex)
    }

    private var topRow: some View {
        Text("\(category) — ATTEMPT \(attempt)")
            .font(.sfMono(size: 11))
            .foregroundColor(.arclabCrimson)
            .tracking(1.1)
            .accessibilityLabel("\(category), attempt \(attempt).")
    }

    private var verb: some View {
        Text(scenario.voice.miss.headline)
            .font(.anton(size: 128))
            .foregroundColor(.arclabWhite)
            .minimumScaleFactor(0.625)
            .lineLimit(1)
            .dynamicTypeSize(.large ... .accessibility1)
    }

    /// v3 audit fix #8: static white rule, no pulse animation.
    /// Decorative crimson cheapened the sacred miss-state semantic.
    private var rule: some View {
        Rectangle()
            .fill(Color.arclabBorderGrey)
            .frame(width: 32, height: 1)
    }

    private var subhead: some View {
        let variants = scenario.outcome.missCategories.first(where: { $0.id == category })?.subheadVariants ?? [:]
        let key: String = attempt >= 3 ? "3+" : "\(attempt)"
        let text = variants[key] ?? variants["1"] ?? category
        return Text(text)
            .font(.barlowCondensed(size: 16, italic: true))
            .foregroundColor(.arclabMidGrey)
    }

    /// Attempt-gated: nil for 1-2, direction hint for 3-4, bracket for 5+.
    private var diagnosticLine: String? {
        if attempt < 3 { return nil }
        if attempt >= 5 {
            return scenario.voice.miss.bracketHintByCategory[category]
        }
        return scenario.voice.miss.diagnosticByCategory[category]
    }

    private var buttonRow: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: onTryAgain) {
                Text(scenario.voice.miss.retryLabel)
                    .font(.sfMono(size: 16, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: Sizing.pillButtonHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .heavy), trigger: false)
            .frame(maxWidth: .infinity)

            // Locked-style on an enabled control so VoiceOver tap order stays intact (HIG pattern).
            // Audit fix: the old 0.3-opacity treatment fell to ~1.4:1 — invisible
            // to low vision — and the unlock rule lived only in the VoiceOver
            // label. Full-strength grey + a lock glyph + the rule in print.
            Button(action: handleSolutionTap) {
                VStack(spacing: 2) {
                    HStack(spacing: Spacing.xxs) {
                        if !isSolutionUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.arclabMidGrey)
                        }
                        Text(scenario.voice.solutionLabel)
                            .font(.sfMono(size: 16, weight: .medium))
                            .foregroundColor(.arclabMidGrey)
                            .tracking(2.5)
                    }
                    if !isSolutionUnlocked {
                        Text("AFTER ATTEMPT 3")
                            .font(.sfMono(size: 9))
                            .foregroundColor(.arclabMidGrey)
                            .tracking(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 160)
            .accessibilityLabel(isSolutionUnlocked ? "Solution, available." : "Solution, locked. Available after attempt 3.")
            .accessibilityHint(isSolutionUnlocked ? "" : "Unavailable")
        }
    }

    private var isSolutionUnlocked: Bool {
        attempt >= 3
    }

    @State private var solutionTapCount: Int = 0

    private func handleSolutionTap() {
        solutionTapCount += 1
        if isSolutionUnlocked {
            onSolution()
        }
    }
}

private extension Color {
    init(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
