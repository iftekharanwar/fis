import SwiftUI

/// v3 single-unknown input — one bordered input card, custom numpad, SHOOT pill.
/// Used by Level Type A (find θ), B (find v), C (find d). The unknown variable
/// is determined by the scenario's `input.mode` (NUMPAD_SINGLE_THETA / _V / _D).
///
/// Mirrors `PlayInputView`'s numpad chrome + haptic feedback exactly — the only
/// structural difference is one input card instead of two, and no auto-focus.
struct PlayInputSingleFieldView: View {
    let scenario: ScenarioDefinition

    /// The single unknown's text binding. PlayView owns the @State.
    @Binding var value: String

    let onShoot: () -> Void

    /// Owned externally so PlayView can hide the numpad to reveal the full court.
    @Binding var isNumpadVisible: Bool

    /// The single Field def from the scenario (input.fields[0]). Resolved at body time.
    private var field: InputDefinition.Field {
        scenario.input.fields[0]
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            inputCardRow
            if isNumpadVisible {
                Numpad(onDigit: handleDigit, onBackspace: handleBackspace)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            shootButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .animation(.easeOut(duration: 0.25), value: isNumpadVisible)
    }

    private var inputCardRow: some View {
        // v3 audit fix #9: single card sized at 2/3 width — the dual-field
        // layout gave each card half the width, this single field deserves
        // more presence than that without filling the full width which
        // would look indecisive.
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            InputCard(field: field, value: $value, isActive: true)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.xl)   // pulls card in to ~ 2/3 of row
    }

    private var shootButton: some View {
        // Audit fix: the 0.3-opacity disabled treatment fell to ~1:1 —
        // invisible to low vision. White-vs-grey text carries the state at
        // full contrast; the border stays printed.
        Button(action: handleShoot) {
            Text(scenario.input.submitLabel)
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(isShootEnabled ? .arclabWhite : .arclabMidGrey)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy), trigger: shootTapsCount, condition: { _, _ in isShootEnabled })
        .sensoryFeedback(.warning, trigger: shootTapsCount, condition: { _, _ in !isShootEnabled })
        .accessibilityLabel(isShootEnabled ? "Shoot. Commit your answer." : "Shoot, awaiting input. Fill the field.")
    }

    @State private var shootTapsCount: Int = 0

    private var isShootEnabled: Bool {
        !value.isEmpty
    }

    private func handleShoot() {
        shootTapsCount += 1
        guard isShootEnabled else { return }
        onShoot()
    }

    private func handleDigit(_ digit: String) {
        var current = value
        if digit == "." && current.contains(".") { return }
        if let dotIdx = current.firstIndex(of: "."),
           digit != "." {
            let decimalsSoFar = current.distance(from: current.index(after: dotIdx), to: current.endIndex)
            if decimalsSoFar >= field.decimals { return }
        }
        current.append(digit)
        if let parsed = Double(current), parsed > field.max { return }
        value = current
    }

    private func handleBackspace() {
        if !value.isEmpty {
            value.removeLast()
        }
    }
}

private struct InputCard: View {
    let field: InputDefinition.Field
    @Binding var value: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                if value.isEmpty {
                    if isActive {
                        Text("|")
                            .font(.sfMono(size: 22, weight: .medium))
                            .foregroundColor(.arclabWhite)
                    } else {
                        Text(" ")
                            .font(.sfMono(size: 22, weight: .medium))
                    }
                } else {
                    Text(value)
                        .font(.sfMono(size: 22, weight: .medium))
                        .foregroundColor(.arclabWhite)
                    Text(field.unit)
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                }
                Spacer()
            }

            Text(rangeText)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                .stroke(
                    isActive ? Color.arclabWhite : Color.arclabBorderGrey,
                    lineWidth: Sizing.borderWidth
                )
        )
    }

    private var rangeText: String {
        "\(formatRangeNum(field.min))\(field.unit) — \(formatRangeNum(field.max))\(field.unit)"
    }

    private func formatRangeNum(_ n: Double) -> String {
        String(format: "%g", n)
    }
}

private struct Numpad: View {
    let onDigit: (String) -> Void
    let onBackspace: () -> Void

    private let layout: [[NumpadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.digit("."), .digit("0"), .backspace]
    ]

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(0..<layout.count, id: \.self) { row in
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<layout[row].count, id: \.self) { col in
                        NumpadButton(key: layout[row][col]) { key in
                            switch key {
                            case .digit(let d): onDigit(d)
                            case .backspace: onBackspace()
                            }
                        }
                    }
                }
            }
        }
    }
}

private enum NumpadKey: Sendable, Equatable {
    case digit(String)
    case backspace
}

private struct NumpadButton: View {
    let key: NumpadKey
    let onTap: (NumpadKey) -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button {
            tapCount += 1
            onTap(key)
        } label: {
            label
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(borderOverlay)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel(accessibilityName)
    }

    /// "delete" for the glyph key; digits read themselves ("5", "point").
    private var accessibilityName: String {
        switch key {
        case .digit("."): return "decimal point"
        case .digit(let d): return d
        case .backspace: return "delete"
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch key {
        case .digit:
            RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
        case .backspace:
            EmptyView()
        }
    }

    @ViewBuilder
    private var label: some View {
        switch key {
        case .digit(let d):
            Text(d)
                .font(.sfMono(size: 20, weight: .medium))
                .foregroundColor(.arclabWhite)
        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.arclabMidGrey)
        }
    }
}
