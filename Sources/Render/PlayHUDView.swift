import SwiftUI

/// SCENARIO PLAY's top HUD — variable strip + LV chip, with optional ✕ CLOSE.
struct PlayHUDView: View {
    let scenario: ScenarioDefinition

    /// nil = chip suppressed entirely (e.g., during ACTION to prevent mid-flight escape).
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Spacing.sm)

            HStack(alignment: .center, spacing: Spacing.sm) {
                if let onClose {
                    CloseChip(onTap: onClose)
                } else {
                    // Reserve the slot so the LV chip doesn't reflow when CLOSE toggles.
                    Color.clear.frame(width: 1, height: 1)
                }
                Spacer()
                LevelChip(subtitle: scenario.meta.subtitle)
            }
            .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.sm)

            HStack(spacing: Spacing.sm) {
                ForEach(Array(scenario.situation.variables.enumerated()), id: \.offset) { _, variable in
                    VariableInlineCell(variable: variable)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)

            Spacer()

            Rectangle()
                .fill(Color.arclabBorderGrey)
                .frame(height: 1)
        }
        .frame(height: 140)
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
                .tracking(1.1)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel("Close. Return to level select.")
    }

    private func handleTap() {
        tapCount += 1
        onTap()
    }
}

private struct VariableInlineCell: View {
    let variable: SituationDefinition.VariableSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(variable.label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(formattedValue)
                    .font(.sfMono(size: 14, weight: .medium))
                    .foregroundColor(.arclabWhite)
                Text(variable.unit)
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
            }
        }
    }

    private var formattedValue: String {
        String(format: "%g", variable.value)
    }
}

/// "LV 01" chip derived from meta.subtitle by parsing the trailing number.
private struct LevelChip: View {
    let subtitle: String

    var body: some View {
        Text(parsedLevelCode)
            .font(.sfMono(size: 11))
            .foregroundColor(.arclabWhite)
            .tracking(1.1)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
    }

    /// "FREE THROW — LEVEL 01" → "LV 01"; falls back to the last token.
    private var parsedLevelCode: String {
        let components = subtitle.split(separator: " ")
        if let last = components.last, components.dropLast().last == "LEVEL" {
            return "LV \(last)"
        }
        return String(components.last ?? "LV")
    }
}
