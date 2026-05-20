import SwiftUI

/// Post-level worked-solution screen.
struct SolutionView: View {
    let scenario: ScenarioDefinition
    let attempt: Int
    let onClose: () -> Void
    let onTryCanonical: (_ theta: Double, _ v: Double) -> Void

    var body: some View {
        ZStack {
            Color.arclabBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                topZone
                    .padding(.horizontal, Spacing.md)

                Spacer().frame(height: Spacing.lg)

                canonicalArcZone

                Spacer().frame(height: Spacing.lg)

                solutionZone
                    .padding(.horizontal, Spacing.md)

                Spacer()

                bottomButton
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .statusBarHidden(true)
    }

    private var topZone: some View {
        HStack(alignment: .center) {
            Button(action: handleClose) {
                Text("✕ CLOSE")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(1.1)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: closeTapCount)
            .accessibilityLabel("Close. Return to missed screen.")

            Spacer()

            Text("SOLUTION")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            Spacer()

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
    }

    private var parsedLevelCode: String {
        let components = scenario.meta.subtitle.split(separator: " ")
        if let last = components.last, components.dropLast().last == "LEVEL" {
            return "LV \(last)"
        }
        return String(components.last ?? "LV")
    }

    @State private var closeTapCount: Int = 0
    private func handleClose() {
        closeTapCount += 1
        onClose()
    }

    private var canonicalArcZone: some View {
        VStack(spacing: Spacing.xs) {
            Text("THE ANSWER")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            Rectangle()
                .fill(Color.arclabWhite)
                .frame(width: 24, height: 1)
        }
    }

    private var solutionZone: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            answerStrip
            if let solution = scenario.solution {
                if !solution.equations.isEmpty {
                    equationsSection(equations: solution.equations)
                }
                if !solution.workedSteps.isEmpty {
                    substitutingSection(steps: solution.workedSteps)
                }
            }
        }
    }

    private var answerStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("ANSWER")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            HStack(spacing: 0) {
                statCell(value: "\(Int(canonicalTheta.rounded()))°", label: "ANGLE")
                divider
                statCell(value: String(format: "%.2f", canonicalVelocity), label: "m/s")
                divider
                // "WOULD EARN" instead of "WOULD HAVE EARNED" — the latter truncates at iPhone 17 width.
                statCell(value: "+\(wouldHaveEarned)", label: "WOULD EARN")
            }
            .frame(height: 64)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.anton(size: 36))
                .foregroundColor(.arclabWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.arclabBorderGrey)
            .frame(width: 1)
            .padding(.vertical, Spacing.xxs)
    }

    private func equationsSection(equations: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("THE MATH")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(equations.enumerated()), id: \.offset) { _, eq in
                    Text(eq)
                        .font(.sfMono(size: 16))
                        .foregroundColor(.arclabWhite)
                }
            }
        }
    }

    private func substitutingSection(steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SUBSTITUTING")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    Text(step)
                        .font(.sfMono(size: 14))
                        .foregroundColor(.arclabWhite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @State private var bottomTapCount: Int = 0

    private var bottomButton: some View {
        Button(action: handleTryCanonical) {
            Text("TRY THIS ANSWER →")
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy), trigger: bottomTapCount)
        .accessibilityLabel("Try this answer. The fields will pre-fill with the canonical answer.")
    }

    private func handleTryCanonical() {
        bottomTapCount += 1
        onTryCanonical(canonicalTheta, canonicalVelocity)
    }

    private var canonicalTheta: Double {
        scenario.outcome.ghostArc?.answer["theta"] ?? 0
    }

    private var canonicalVelocity: Double {
        scenario.outcome.ghostArc?.answer["v"] ?? 0
    }

    private var wouldHaveEarned: Int {
        let base = Double(scenario.outcome.baseScore)
        let swishMultiplier = scenario.outcome.successFlavors
            .first(where: { $0.id == "SWISH" })?
            .scoreMultiplier ?? 1.0
        return Int((base * swishMultiplier).rounded())
    }
}
