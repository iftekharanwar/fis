import SwiftUI

/// Per-sport level list.
struct LevelSelectView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    let sport: Sport

    @State private var presentedScenario: ScenarioDefinition?
    @State private var loadError: ScenarioLoadError?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer().frame(height: geo.safeAreaInsets.top + Spacing.xs)

                topBar
                    .padding(.horizontal, Spacing.md)

                Spacer().frame(height: Spacing.xl)

                sectionHeading
                    .padding(.horizontal, Spacing.md)

                Spacer().frame(height: Spacing.lg)

                levelList
                    .padding(.horizontal, Spacing.md)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.arclabBlack)
        }
        .statusBarHidden(false)
        .fullScreenCover(item: $presentedScenario) { scenario in
            ScenarioContainerView(scenario: scenario)
        }
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: sport.displayName, action: { dismiss() }),
            trailing: .label(profile.profile.rankRung.description)
        )
    }

    private var sectionHeading: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(sport.physicsDomainSubhead)
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            Text(sectionTitle)
                .font(.anton(size: 32))
                .foregroundColor(.arclabWhite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: String {
        switch sport {
        case .basketball: return "FREE THROW."
        case .soccer:     return "FREE KICK."
        case .pool:       return "BREAK SHOT."
        case .archery:    return "TARGET PRACTICE."
        case .f1:         return "BRAKING ZONE."
        }
    }

    private var levelList: some View {
        let entries = SportLevelCatalog.levels(for: sport)
        return VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries) { entry in
                    LevelRow(
                        entry: entry,
                        record: profile.profile.completedScenarios[entry.scenarioId],
                        onTap: { handleTap(entry) }
                    )
                    if entry.id != entries.last?.id {
                        Rectangle()
                            .fill(Color.arclabBorderGrey)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Text("NO LEVELS YET.")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)
            Text("This sport is in training.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
        }
        .padding(.vertical, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private func handleTap(_ entry: SportLevelCatalog.LevelEntry) {
        do {
            presentedScenario = try ScenarioLoader.load(entry.scenarioId)
        } catch let error as ScenarioLoadError {
            loadError = error
        } catch {
            loadError = .malformedJSON(scenarioId: entry.scenarioId, underlying: error.localizedDescription)
        }
    }
}

private struct LevelRow: View {
    let entry: SportLevelCatalog.LevelEntry
    let record: ScenarioRecord?
    let onTap: () -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text(rowText)
                    .font(.sfMono(size: 14, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(1.5)

                Spacer()

                if isCompleted {
                    Text("✓")
                        .font(.sfMono(size: 14))
                        .foregroundColor(.arclabMidGrey)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rowText: String {
        let prefix = String(format: "LEVEL %02d", entry.levelNumber)
        return "\(prefix) — \(entry.shortLabel)"
    }

    private var isCompleted: Bool {
        record?.firstCompletedAt != nil
    }

    private var accessibilityLabel: String {
        let prefix = "Level \(entry.levelNumber). \(entry.shortLabel)"
        if isCompleted {
            return "\(prefix) Completed."
        }
        return prefix
    }

    private func handleTap() {
        tapCount += 1
        onTap()
    }
}

extension ScenarioDefinition: Identifiable {
    public var id: ScenarioID { scenarioId }
}
