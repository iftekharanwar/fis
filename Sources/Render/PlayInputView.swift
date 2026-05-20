import SwiftUI

/// SCENARIO PLAY's input zone — two bordered input cards, custom numpad, SHOOT pill.
struct PlayInputView: View {
    let scenario: ScenarioDefinition

    @Binding var thetaValue: String
    @Binding var velocityValue: String
    @Binding var activeField: InputField

    let onShoot: () -> Void

    enum InputField: Sendable, Equatable {
        case theta
        case velocity
    }

    /// Owned externally so PlayView can hide the numpad to reveal the full court.
    @Binding var isNumpadVisible: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            inputCardsRow
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

    private var inputCardsRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(scenario.input.fields.enumerated()), id: \.offset) { _, field in
                InputCard(
                    field: field,
                    value: bindingFor(field: field),
                    isActive: activeFieldForFieldDef(field: field) == activeField
                )
                .onTapGesture {
                    activeField = activeFieldForFieldDef(field: field)
                }
            }
        }
    }

    private func bindingFor(field: InputDefinition.Field) -> Binding<String> {
        switch field.name {
        case "theta": return $thetaValue
        case "v": return $velocityValue
        default: return .constant("")
        }
    }

    private func activeFieldForFieldDef(field: InputDefinition.Field) -> InputField {
        field.name == "theta" ? .theta : .velocity
    }

    private var shootButton: some View {
        Button(action: handleShoot) {
            Text(scenario.input.submitLabel)
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabWhite)
                .opacity(isShootEnabled ? 1.0 : 0.3)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey.opacity(isShootEnabled ? 1.0 : 0.3),
                                lineWidth: Sizing.borderWidth)
                )
        }
        .buttonStyle(.plain)
        // Stays enabled in code (not .disabled) so tap-while-invalid fires .warning haptic and stays in VoiceOver tap order.
        .sensoryFeedback(.impact(weight: .heavy), trigger: shootTapsCount, condition: { _, _ in isShootEnabled })
        .sensoryFeedback(.warning, trigger: shootTapsCount, condition: { _, _ in !isShootEnabled })
        .accessibilityLabel(isShootEnabled ? "Shoot. Commit your answer." : "Shoot, awaiting input. Both fields must be filled.")
    }

    @State private var shootTapsCount: Int = 0

    private var isShootEnabled: Bool {
        !thetaValue.isEmpty && !velocityValue.isEmpty
    }

    private func handleShoot() {
        shootTapsCount += 1
        guard isShootEnabled else { return }
        onShoot()
    }

    private func handleDigit(_ digit: String) {
        let binding = activeField == .theta ? $thetaValue : $velocityValue
        let field = activeField == .theta ? scenario.input.fields[0] : scenario.input.fields[1]
        var current = binding.wrappedValue
        // Decimal validation: one dot max, respect `decimals` cap.
        if digit == "." && current.contains(".") { return }
        if let dotIdx = current.firstIndex(of: "."),
           digit != "." {
            let decimalsSoFar = current.distance(from: current.index(after: dotIdx), to: current.endIndex)
            if decimalsSoFar >= field.decimals { return }
        }
        current.append(digit)
        // Range gate.
        if let parsed = Double(current), parsed > field.max { return }
        binding.wrappedValue = current

        autoFocusIfFieldLooksDone(field: field, value: current)
    }

    /// Conservative auto-advance — only fires when the current field can't reasonably accept another digit.
    private func autoFocusIfFieldLooksDone(field: InputDefinition.Field, value: String) {
        guard activeField == .theta else { return }
        if let dotIdx = value.firstIndex(of: ".") {
            let decimalsSoFar = value.distance(from: value.index(after: dotIdx), to: value.endIndex)
            if decimalsSoFar >= field.decimals {
                activeField = .velocity
            }
        } else if value.count >= 2,
                  let parsed = Double(value),
                  parsed * 10 > field.max {
            // Another digit would overflow the range.
            activeField = .velocity
        }
    }

    private func handleBackspace() {
        let binding = activeField == .theta ? $thetaValue : $velocityValue
        if !binding.wrappedValue.isEmpty {
            binding.wrappedValue.removeLast()
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
                        // Reserve vertical space so empty inactive card matches active height.
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
                .frame(height: 40)
                .overlay(borderOverlay)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }

    /// Backspace gets no border (Apple Calculator modifier-key treatment); digits get the standard chip.
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
