import SwiftUI

/// Shared compute-dock parameter row: caption + live readout over a slider
/// flanked by − / + step chips. One component for all three sports so the
/// row reads, speaks, and steps the same everywhere.
///
/// The chips are the non-drag alternative WCAG 2.5.7 requires (a drag-only
/// slider locks out tremor and switch users) — and they double as fine
/// adjustment for everyone: drag to get close, tap to dial in.
struct ParameterSliderRow: View {
    /// Visual caption, e.g. "ANGLE" (sfMono uppercase).
    let label: String
    /// What VoiceOver calls the control, e.g. "Launch angle".
    let spokenName: String
    /// Visual unit suffix, e.g. "°".
    let unit: String
    /// Spoken unit, e.g. "degrees".
    let spokenUnit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    /// Step applied by the − / + chips (and spoken VoiceOver adjustments).
    let step: Double
    var tint: Color = .arclabWhite

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: format, value))
                        .font(.sfMono(size: 18, weight: .medium))
                        .foregroundColor(.arclabWhite)
                    Text(unit)
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                }
            }
            .accessibilityHidden(true)  // the slider speaks name + value itself

            HStack(spacing: Spacing.xs) {
                stepChip(symbol: "minus", verb: "Decrease") {
                    value = max(range.lowerBound, value - step)
                }
                Slider(value: $value, in: range)
                    .tint(tint)
                    .accessibilityLabel(spokenName)
                    .accessibilityValue("\(String(format: format, value)) \(spokenUnit)")
                stepChip(symbol: "plus", verb: "Increase") {
                    value = min(range.upperBound, value + step)
                }
            }
        }
    }

    private func stepChip(symbol: String, verb: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.arclabWhite)
                .frame(width: Sizing.minTapTarget, height: Sizing.minTapTarget)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(verb) \(spokenName)")
    }
}

#Preview {
    struct Host: View {
        @State var theta = 50.0
        @State var v = 7.0
        var body: some View {
            VStack(spacing: Spacing.md) {
                ParameterSliderRow(
                    label: "ANGLE", spokenName: "Launch angle",
                    unit: "°", spokenUnit: "degrees",
                    value: $theta, range: 15...80, format: "%.0f", step: 1
                )
                ParameterSliderRow(
                    label: "SPEED", spokenName: "Launch speed",
                    unit: "m/s", spokenUnit: "meters per second",
                    value: $v, range: 3...15, format: "%.1f", step: 0.5,
                    tint: .arclabRimOrange
                )
            }
            .padding()
            .background(Color.arclabBlack)
        }
    }
    return Host()
}
