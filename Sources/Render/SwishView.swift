import SwiftUI

/// SWISH / SUCCESS screen — also functions as the share asset.
struct SwishView: View {
    let scenario: ScenarioDefinition
    let flavor: String          // "SWISH" | "GLASS" | "RIM_DROP"
    let theta: Double
    let velocity: Double
    let score: Int
    let isFirstTryClean: Bool   // controls watermark visibility (inverted rule)
    let xpGained: Int

    let onNextLevel: () -> Void
    let onReplay: () -> Void

    @State private var verbScale: CGFloat = UIAccessibility.isReduceMotionEnabled ? 1.0 : 0.85

    /// Count-up progress per stat cell (0...1). Drives the interpolation from
    /// 0 to the cell's final value on appear. Staggered for celebration rhythm.
    @State private var thetaCount: Double = UIAccessibility.isReduceMotionEnabled ? 1 : 0
    @State private var velocityCount: Double = UIAccessibility.isReduceMotionEnabled ? 1 : 0
    @State private var scoreCount: Double = UIAccessibility.isReduceMotionEnabled ? 1 : 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Spacing.lg)
                flavorCaption
                Spacer().frame(height: Spacing.sm)
                verb
                Spacer().frame(height: Spacing.md)
                rule
                Spacer().frame(height: Spacing.sm)
                subhead
                Spacer()
                statStrip
                Spacer().frame(height: Spacing.sm)
                xpLine
                Spacer().frame(height: Spacing.lg)
                buttonRow
                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isFirstTryClean {
                watermark
                    .padding(.trailing, Spacing.sm)
                    .padding(.bottom, Spacing.sm + Spacing.xxl + Sizing.pillButtonHeight + Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                verbScale = 1.0
            }
            // Stat count-up — staggered so they don't all hit final at once.
            withAnimation(.easeOut(duration: 0.7).delay(0.0)) { thetaCount = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { velocityCount = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) { scoreCount = 1 }
        }
    }

    private var flavorCaption: some View {
        Text(scenario.voice.success.flavorCaption[flavor] ?? flavor)
            .font(.sfMono(size: 11))
            .foregroundColor(.arclabMidGrey)
            .tracking(1.1)
    }

    private var verb: some View {
        Text(scenario.voice.success.headlineByFlavor[flavor] ?? flavor)
            .font(.anton(size: 128))
            .foregroundColor(.arclabWhite)
            .minimumScaleFactor(0.625)
            .lineLimit(1)
            .dynamicTypeSize(.large ... .accessibility1)
            .scaleEffect(verbScale, anchor: .leading)
            .accessibilityLabel("\(flavor), success.")
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.arclabWhite)
            .frame(width: 24, height: 1)
    }

    private var subhead: some View {
        Text(scenario.voice.success.subheadByFlavor[flavor] ?? "")
            .font(.barlowCondensed(size: 16, italic: true))
            .foregroundColor(.arclabMidGrey)
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(Int((theta * thetaCount).rounded()))°",
                     label: scenario.voice.success.statLabels.theta)
            divider
            statCell(value: String(format: "%.2f", velocity * velocityCount),
                     label: scenario.voice.success.statLabels.v)
            divider
            statCell(value: "+\(Int((Double(score) * scoreCount).rounded()))",
                     label: scenario.voice.success.statLabels.score)
        }
        .frame(height: 64)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.anton(size: 36))
                .foregroundColor(.arclabWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.arclabBorderGrey)
            .frame(width: 1)
            .padding(.vertical, Spacing.xxs)
    }

    private var xpLine: some View {
        Text("+\(xpGained) XP")
            .font(.sfMono(size: 11))
            .foregroundColor(.arclabWhite)
            .tracking(1.1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var buttonRow: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: onNextLevel) {
                Text(scenario.voice.nextLabel)
                    .font(.sfMono(size: 16, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: Sizing.pillButtonHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .sensoryFeedback(.impact(weight: .heavy), trigger: false)

            Button(action: onReplay) {
                Text(scenario.voice.replayLabel)
                    .font(.sfMono(size: 16, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: Sizing.pillButtonHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 160)
        }
    }

    private var watermark: some View {
        Text("ARCLAB")
            .font(.sfMono(size: 9))
            .foregroundColor(.arclabMidGrey)
            .tracking(1.1)
    }
}
