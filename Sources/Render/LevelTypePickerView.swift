import SwiftUI

/// v3 §3.1.3 — Level Type picker. The chapter detail screen: shows the 4
/// level types of a chapter as rows with mastery-bar progress chips, plus
/// the lesson card on top and a Famous Moments row at the bottom (the row
/// reads "Coming soon." until the replay feature lands in v3.1).
struct LevelTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    let chapter: Chapter
    let onSelectLevelType: (LevelTypeID) -> Void
    let onOpenFamousMoments: () -> Void

    /// Drives the expanding lesson reader (replaces the old full-screen push).
    @State private var lessonExpanded = false

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar
                Spacer().frame(height: Spacing.xl)
                heading
                Spacer().frame(height: Spacing.lg)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        lessonRow
                        Spacer().frame(height: Spacing.md)
                        levelRows
                        Spacer().frame(height: Spacing.lg)
                        famousMomentsRow
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        // Picker recedes behind the expanding reader.
        .opacity(lessonExpanded ? 0 : 1)
        .scaleEffect(lessonExpanded ? 0.96 : 1)
        .animation(.easeOut(duration: 0.42), value: lessonExpanded)
        .lessonReader(
            isPresented: $lessonExpanded,
            lesson: chapter.lesson,
            chapterTitle: chapter.title,
            chapterIndex: chapter.index,
            onClose: { finished in
                if finished {
                    profile.mutate { $0.completedLessons.insert(chapter.lesson.id) }
                }
                lessonExpanded = false
            }
        )
        .task { autoSelectLevelTypeIfRequested() }
    }

    /// Diagnostic: when ARCLAB_PICK_LEVEL_TYPE is set to "A"|"B"|"C"|"D",
    /// auto-fires onSelectLevelType after picker appears. For natural-flow
    /// playtest verification — proves the picker → router → NextSituationPicker
    /// → PlayView chain is wired without needing a tap.
    private func autoSelectLevelTypeIfRequested() {
        guard let raw = ProcessInfo.processInfo.environment["ARCLAB_PICK_LEVEL_TYPE"] else { return }
        let lt: LevelTypeID?
        switch raw {
        case "A": lt = .findTheta
        case "B": lt = .findV
        case "C": lt = .findD
        case "D": lt = .findBoth
        default:  lt = nil
        }
        if let lt {
            print("[arclab/picker] auto-selecting levelType=\(lt.rawValue) (ARCLAB_PICK_LEVEL_TYPE=\(raw))")
            // Small delay so the picker appears on screen first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSelectLevelType(lt)
            }
        }
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: chapter.sport.displayName, action: { dismiss() }),
            trailing: .label("CHAPTER \(chapter.index)")
        )
    }

    private var heading: some View {
        Text(chapter.title.uppercased())
            .font(.anton(size: 64))
            .foregroundColor(.arclabWhite)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lessonRow: some View {
        Button(action: { lessonExpanded = true }) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("LESSON · \(chapter.lesson.estimatedReadSeconds)s")
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)

                Text(chapter.lesson.title)
                    .font(.anton(size: 22))
                    .foregroundColor(.arclabWhite)

                Text(chapter.lesson.oneLiner)
                    .font(.barlowCondensed(size: 13, italic: true))
                    .foregroundColor(.arclabMidGrey)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var levelRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(LevelTypeID.earthChapterTypes.enumerated()), id: \.offset) { index, lt in
                LevelTypeRow(
                    chapter: chapter,
                    levelType: lt,
                    mastery: masteryFor(lt),
                    isUnlocked: isUnlocked(lt),
                    onTap: { onSelectLevelType(lt) }
                )
                if index < LevelTypeID.earthChapterTypes.count - 1 {
                    Rectangle()
                        .fill(Color.arclabBorderGrey)
                        .frame(height: 1)
                }
            }
        }
    }

    private var famousMomentsRow: some View {
        // v3 ship: the Famous Moments replay flow lands in v3.1. Until then
        // the row stays non-interactive — copy reflects "coming soon" so a
        // mastered player doesn't tap a live-looking row and get nothing.
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.arclabMidGrey)
                .opacity(0.4)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("FAMOUS MOMENTS")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Text("Coming soon.")
                    .font(.barlowCondensed(size: 13, italic: true))
                    .foregroundColor(.arclabMidGrey)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .accessibilityLabel("Famous Moments. Coming soon.")
    }

    // MARK: - Mastery lookups

    private func masteryFor(_ lt: LevelTypeID) -> LevelTypeMastery? {
        let key = masteryKey(for: lt)
        return profile.profile.levelTypeMasteries[key]
    }

    private func masteryKey(for lt: LevelTypeID) -> String {
        "\(chapter.id).\(lt.rawValue)"
    }

    /// v3 progression: A is always unlocked; B+ require prior to be MASTERED.
    /// Per locked spec §2.4 — preview attempts after 3 attempts on prior are
    /// allowed in the runtime but not surfaced from this picker yet.
    private func isUnlocked(_ lt: LevelTypeID) -> Bool {
        switch lt {
        case .findTheta:
            return true
        case .findV:
            return masteryFor(.findTheta)?.status == .mastered
        case .findD:
            return masteryFor(.findV)?.status == .mastered
        case .findBoth:
            return masteryFor(.findD)?.status == .mastered
        case .findG:
            return false   // off-Earth, not in Earth chapters
        }
    }
}

// MARK: - Row

private struct LevelTypeRow: View {
    let chapter: Chapter
    let levelType: LevelTypeID
    let mastery: LevelTypeMastery?
    let isUnlocked: Bool
    let onTap: () -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text(levelType.shortLabel)
                    .font(.anton(size: 28))
                    .foregroundColor(isUnlocked ? .arclabMidGrey : .arclabMidGrey.opacity(0.4))
                    .frame(width: 36, alignment: .leading)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(levelType.title)
                        .font(.anton(size: 22))
                        .foregroundColor(isUnlocked ? .arclabWhite : .arclabMidGrey)
                        .opacity(isUnlocked ? 1.0 : 0.5)
                        .lineLimit(1)

                    Text(levelType.subtitle)
                        .font(.barlowCondensed(size: 13, italic: true))
                        .foregroundColor(.arclabMidGrey)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                MasteryChip(mastery: mastery, isUnlocked: isUnlocked)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount, condition: { _, _ in isUnlocked })
        .sensoryFeedback(.warning, trigger: tapCount, condition: { _, _ in !isUnlocked })
        .accessibilityLabel("\(levelType.shortLabel). \(levelType.title). \(isUnlocked ? "Unlocked." : "Locked.")")
    }

    private func handleTap() {
        tapCount += 1
        if isUnlocked { onTap() }
    }
}

// MARK: - Mastery chip

private struct MasteryChip: View {
    let mastery: LevelTypeMastery?
    let isUnlocked: Bool

    var body: some View {
        if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.arclabMidGrey)
                .accessibilityLabel("Locked")
        } else if let m = mastery, m.status == .mastered {
            Text("✓")
                .font(.sfMono(size: 14, weight: .medium))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabWhite, lineWidth: Sizing.borderWidth)
                )
        } else {
            // Progress chip: e.g. "3 / 6". Hidden at zero attempts so
            // first-contact rows don't read "0 / 6" (mildly demoralizing).
            let attempts = mastery?.attemptHistory.count ?? 0
            if attempts > 0 {
                let bar = min(attempts, LevelTypeMastery.masteryWindowSize)
                Text("\(bar) / \(LevelTypeMastery.masteryWindowSize)")
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
    }
}

// MARK: - LevelTypeID display helpers

extension LevelTypeID {
    /// The four Earth-chapter level types per GAME_v3_LOCKED.md §2.2.
    static let earthChapterTypes: [LevelTypeID] = [.findTheta, .findV, .findD, .findBoth]

    var shortLabel: String {
        switch self {
        case .findTheta: return "A."
        case .findV:     return "B."
        case .findD:     return "C."
        case .findBoth:  return "D."
        case .findG:     return "E."
        }
    }

    var title: String {
        switch self {
        case .findTheta: return "FIND THE ANGLE."
        case .findV:     return "FIND THE SPEED."
        case .findD:     return "PICK THE SPOT."
        case .findBoth:  return "FIND BOTH."
        case .findG:     return "FIND GRAVITY."
        }
    }

    var subtitle: String {
        switch self {
        case .findTheta: return "Speed and distance set. One unknown."
        case .findV:     return "Angle and distance set. One unknown."
        case .findD:     return "Angle and speed set. Find where it lands."
        case .findBoth:  return "Two unknowns. The chapter capstone."
        case .findG:     return "Trajectory given. Find the gravity."
        }
    }
}
