import SwiftUI

/// Sport picker — reached from Home's CONTINUE row. Back goes to Home.
struct SportPickerView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Sport) -> Void

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                Spacer().frame(height: Spacing.xl)

                pickHeading

                Spacer().frame(height: Spacing.lg)

                // ScrollView prevents F1 row clipping on iPhone 17 and contains layout bounds.
                ScrollView(.vertical, showsIndicators: false) {
                    sportList
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        .statusBarHidden(false)
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: "Home", action: { dismiss() }),
            trailing: .stacked(
                primary: profile.profile.rankRung.description,
                secondary: xpProgressLine
            )
        )
    }

    private var xpProgressLine: String {
        let current = profile.profile.totalXP
        if let remaining = RankRung.xpToNext(currentXP: current) {
            let nextThreshold = current + remaining
            return "\(current) / \(nextThreshold) XP"
        }
        return "\(current) XP — MAX"
    }

    private var pickHeading: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PICK A SPORT.")
                .font(.anton(size: 32))
                .foregroundColor(.arclabWhite)

            Text("Each sport moves a different way.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sportList: some View {
        VStack(spacing: 0) {
            ForEach(Sport.sortedForPicker) { sport in
                SportRow(
                    sport: sport,
                    onTap: { handleTap(sport) }
                )
                if sport != Sport.sortedForPicker.last {
                    Rectangle()
                        .fill(Color.arclabBorderGrey)
                        .frame(height: 1)
                }
            }
        }
    }

    @State private var lockedTapCount: Int = 0

    private func handleTap(_ sport: Sport) {
        if sport.isUnlocked {
            onSelect(sport)
        } else {
            lockedTapCount += 1
        }
    }
}

private struct SportRow: View {
    let sport: Sport
    let onTap: () -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: sport.sfSymbolName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(sport.isUnlocked ? .arclabWhite : .arclabMidGrey)
                    .opacity(sport.isUnlocked ? 1.0 : 0.5)
                    .frame(width: 36, alignment: .leading)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(sport.displayName)
                        .font(.anton(size: 48))
                        .foregroundColor(sport.isUnlocked ? .arclabWhite : .arclabMidGrey)
                        .opacity(sport.isUnlocked ? 1.0 : 0.5)

                    Text(sport.physicsDomainSubhead)
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(1.1)
                }

                Spacer()

                if !sport.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.arclabMidGrey)
                        .accessibilityLabel("Locked")
                }
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount, condition: { _, _ in sport.isUnlocked })
        .sensoryFeedback(.warning, trigger: tapCount, condition: { _, _ in !sport.isUnlocked })
        .accessibilityLabel("\(sport.displayName). \(sport.physicsDomainSubhead). \(sport.isUnlocked ? "Unlocked." : "Locked.")")
    }

    private func handleTap() {
        tapCount += 1
        onTap()
    }
}
