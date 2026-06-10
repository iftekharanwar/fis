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
                LevelChip(meta: scenario.meta)
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

            Spacer().frame(height: Spacing.sm)

            Rectangle()
                .fill(Color.arclabBorderGrey)
                .frame(height: 1)
        }
        // v3 polish: 140pt was the chrome reserve from an earlier draft that
        // included a sport-mode toggle. With CLOSE + LV chip row + variable
        // strip the actual content is ~88pt; trimming to 100pt gives the
        // court ~40pt more vertical headroom without crowding the chrome.
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
                .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .gameHaptic(.impact(weight: .light), trigger: tapCount)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(variable.unit)
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .lineLimit(1)
            }
        }
    }

    private var formattedValue: String {
        String(format: "%g", variable.value)
    }
}

/// Top-right chip. v3: derives from meta.levelType when present
/// ("LV A · FIND θ" etc). Falls back to the v1 "LV 01" subtitle-parser.
private struct LevelChip: View {
    let meta: MetaDefinition

    var body: some View {
        Text(label)
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

    private var label: String {
        // v3 path: derive from explicit levelType.
        if let lt = meta.levelType {
            switch lt {
            case .findTheta: return "LV A · θ"
            case .findV:     return "LV B · V"
            case .findD:     return "LV C · D"
            case .findBoth:  return "LV D · θ+V"
            case .findG:     return "LV E · G"
            }
        }
        // v1 fallback: "FREE THROW — LEVEL 01" → "LV 01"; else last token.
        let components = meta.subtitle.split(separator: " ")
        if let last = components.last, components.dropLast().last == "LEVEL" {
            return "LV \(last)"
        }
        return String(components.last ?? "LV")
    }
}
