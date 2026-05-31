import SwiftUI

/// v3 — milestone celebration screens that fire after PlayView outcomes when
/// a player crosses a meaningful threshold. Two flavors (audit-pared from 4):
///
/// - **levelType** — between-level-type takeover (FOUND THE LIFT., etc.).
///   Fires on the attempt that promotes a level type to .mastered.
/// - **chapterMastery** — every level type of a chapter is mastered.
///   The "lens reveal" moment per spec §3.5.
///
/// Cut from earlier build: `tierUp` (rare, dilutes mastery moments) and
/// `completion` (v3.1+ problem). PlayView queues these into
/// `pendingCelebrations: [Celebration]` and the fullScreenCover fires them
/// one at a time. Tap-anywhere advances.
enum Celebration: Identifiable, Equatable {
    case levelType(LevelTypeID)
    case chapterMastery(chapter: Chapter)

    var id: String {
        switch self {
        case .levelType(let lt): return "lt-\(lt.rawValue)"
        case .chapterMastery(let chapter): return "ch-\(chapter.id)"
        }
    }

    static func == (lhs: Celebration, rhs: Celebration) -> Bool {
        lhs.id == rhs.id
    }
}

/// One celebration screen. Anton headline + Barlow italic body lines +
/// SF Mono "▾ TAP" advance chip. Same visual language as MasteryGate so
/// stacked celebrations feel like one continuous progression beat, not
/// four different screens.
struct CelebrationView: View {
    let celebration: Celebration
    let onTap: () -> Void

    @State private var tapCount: Int = 0
    @State private var appearHapticCount: Int = 0

    var body: some View {
        let config = Self.config(for: celebration)
        ZStack {
            Color.arclabBlack.ignoresSafeArea()

            AdaptiveContentContainer(maxWidth: 600) {
                VStack(spacing: Spacing.xl) {
                    Spacer()

                    Text(config.headline)
                        .font(.anton(size: config.headlineSize))
                        .foregroundColor(.arclabWhite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)

                    VStack(spacing: Spacing.xs) {
                        ForEach(Array(config.body.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.barlowCondensed(size: 18, italic: true))
                                .foregroundColor(.arclabMidGrey)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.lg)
                        }
                    }

                    Spacer()

                    Text("▾ TAP")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)

                    Spacer().frame(height: Spacing.xxl)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tapCount += 1
            onTap()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: tapCount)
        // First-appear celebration haptic — .success for the milestone moment.
        .sensoryFeedback(.success, trigger: appearHapticCount)
        .onAppear { appearHapticCount += 1 }
        .statusBarHidden(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(for: celebration, config: config))
    }

    private struct Config {
        let headline: String
        let headlineSize: CGFloat
        let body: [String]
    }

    private static func config(for celebration: Celebration) -> Config {
        switch celebration {
        case .levelType(let lt):
            let (headline, body) = MasteryGateTakeoverView.config(after: lt)
            return Config(headline: headline, headlineSize: 48, body: body)
        case .chapterMastery(let chapter):
            return Config(
                headline: chapter.title.uppercased() + ".",
                headlineSize: 56,
                body: chapterMasteryBody(for: chapter)
            )
        }
    }

    /// Per-chapter "lens-reveal" body lines. Each line reinforces what
    /// mastering that chapter gives you the language to see.
    private static func chapterMasteryBody(for chapter: Chapter) -> [String] {
        switch chapter.id {
        case "bb-ch1-arc":
            return ["Every shot is the same shape now.",
                    "Chapter 2 is the spin."]
        case "bb-ch2-spin":
            return ["Spin bends the arc you already see.",
                    "Chapter 3 is the fade."]
        case "bb-ch3-fade":
            return ["The body moves under the shot.",
                    "Chapter 4 is the glass."]
        case "bb-ch4-glass":
            return ["The board is a second rim.",
                    "Chapter 5 is the corner three."]
        case "bb-ch5-corner":
            return ["The corner is the test of everything.",
                    "The eye reads the game now."]
        default:
            return ["Locked the lens.",
                    "On to the next."]
        }
    }

    private static func accessibilityLabel(for celebration: Celebration, config: Config) -> String {
        let body = config.body.joined(separator: " ")
        return "\(config.headline). \(body)"
    }
}

#Preview("Chapter mastery") {
    CelebrationView(
        celebration: .chapterMastery(chapter: BasketballCurriculum.chapters[0]),
        onTap: {}
    )
}
