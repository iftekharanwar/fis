import SwiftUI

/// Horizontal strip of physics variables (DIST / HOOP / REL H / G).
struct VariableStrip: View {
    let variables: [SituationDefinition.VariableSpec]
    let staggered: Bool

    init(variables: [SituationDefinition.VariableSpec], staggered: Bool = false) {
        self.variables = variables
        self.staggered = staggered
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(variables.enumerated()), id: \.offset) { index, variable in
                if index > 0 {
                    Rectangle()
                        .fill(Color.arclabBorderGrey)
                        .frame(width: 1)
                        .padding(.vertical, Spacing.xxs)
                }
                VariableCell(variable: variable)
                    .frame(maxWidth: .infinity)
                    .transition(staggered ? .opacity : .identity)
                    .animation(
                        staggered
                            ? .easeOut(duration: 0.25).delay(Double(index) * 0.08)
                            : nil,
                        value: staggered
                    )
            }
        }
        .frame(height: 64)
    }
}

/// One cell of the variable strip.
struct VariableCell: View {
    let variable: SituationDefinition.VariableSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(variable.label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(formattedValue)
                    .font(.sfMono(size: 22, weight: .medium))
                    .foregroundColor(.arclabWhite)
                Text(variable.unit)
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.sm)
        // Read as one phrase ("Distance, 4.6 meters") instead of three
        // fragments VoiceOver would otherwise stop on separately.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(variable.label), \(formattedValue) \(variable.unit)")
    }

    private var formattedValue: String {
        String(format: "%g", variable.value)
    }
}
