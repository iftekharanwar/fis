import Foundation

/// v2.1 basketball curriculum. Chapter 1 is fully authored as a 6-card story;
/// chapters 2–5 are scaffolded as 3-card placeholders, ready to author in
/// the content pass.
enum BasketballCurriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: "bb-ch1-projectile",
            sport: .basketball,
            index: 1,
            title: "The arc",
            subtitle: "Every shot is a projectile. Here's the baseline.",
            lesson: lesson_1_1,
            scenarioIDs: ["bb-freethrow-001"]
        ),
        Chapter(
            id: "bb-ch2-release-height",
            sport: .basketball,
            index: 2,
            title: "Release height",
            subtitle: "Why shooting from your chest fails — even with perfect form.",
            lesson: scaffold(
                id: "bb-l2.1-release-height",
                title: "Why release height dominates at low arcs",
                oneLiner: "Lowering your release by 30cm is 4× harder to compensate than you think.",
                seconds: 90
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "bb-ch3-flat-vs-high",
            sport: .basketball,
            index: 3,
            title: "Flat arc vs high arc",
            subtitle: "The tradeoff between margin and effort.",
            lesson: scaffold(
                id: "bb-l3.1-arc-margin",
                title: "Why a higher arc has more rim margin",
                oneLiner: "A steeper ball sees a wider rim — but costs more speed.",
                seconds: 75
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "bb-ch4-distance",
            sport: .basketball,
            index: 4,
            title: "Distance & range",
            subtitle: "Why a half-court heave needs a 50° launch.",
            lesson: scaffold(
                id: "bb-l4.1-range",
                title: "How distance changes the optimal angle",
                oneLiner: "There's an angle that gives you maximum range — and it's not 45° in real basketball.",
                seconds: 90
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "bb-ch5-off-axis",
            sport: .basketball,
            index: 5,
            title: "Off-balance shots",
            subtitle: "Fadeaways, floaters, drifters — how elite scorers compensate.",
            lesson: scaffold(
                id: "bb-l5.1-lateral-momentum",
                title: "Why drifting sideways tilts every shot",
                oneLiner: "The body's momentum at release becomes the ball's momentum at release.",
                seconds: 120
            ),
            scenarioIDs: []
        )
    ]

    // MARK: - Lesson 1.1 — "The arc" as a 6-card story

    private static let lesson_1_1 = LessonContent(
        id: "bb-l1.1-arc-baseline",
        title: "Why every shot is an arc",
        oneLiner: "Once the ball leaves your hand, only gravity acts on it.",
        estimatedReadSeconds: 60,
        cards: [
            // Card 1 — set the hook
            .init(
                headline: "Every shot is the same shape.",
                body: "Once the ball leaves your hand, you can't change anything. Air doesn't push it. You can't pull it back. There's only one thing left."
            ),
            // Card 2 — name the thing
            .init(
                headline: "Gravity.",
                body: "A constant pull, straight down. 9.8 m/s². Same on every shot you've ever taken."
            ),
            // Card 3 — show the shape
            .init(
                headline: "That's the whole story.",
                body: "Gravity + your release. Two ingredients. They draw the arc the ball follows. Always the same shape — a parabola."
            ),
            // Card 4 — the formula reveal (heavier card)
            .init(
                headline: "And it has an equation.",
                body: "Plug in your release height, your angle, your speed. Gravity does the rest. The math gives you exactly where the ball will be at any moment.",
                math: "y(t) = h + v · sin(θ) · t − ½ · g · t²"
            ),
            // Card 5 — the human takeaway
            .init(
                headline: "Your hand decides everything.",
                body: "If two players release identically, their shots are identical. The arc is set the instant you let go."
            ),
            // Card 6 — close the loop
            .init(
                headline: "Now let's try one.",
                body: "A free throw. You'll watch the shot, call whether it goes in, and we'll show you why."
            )
        ]
    )

    // MARK: - Scaffold helper

    /// Placeholder for chapters whose lessons haven't been authored yet.
    /// Three cards minimum so the story shape still feels right while
    /// authoring is pending.
    private static func scaffold(
        id: String,
        title: String,
        oneLiner: String,
        seconds: Int
    ) -> LessonContent {
        LessonContent(
            id: id,
            title: title,
            oneLiner: oneLiner,
            estimatedReadSeconds: seconds,
            cards: [
                .init(headline: title, body: oneLiner),
                .init(headline: "Story coming soon.", body: "This chapter's lesson is in authoring."),
                .init(headline: "Ready to practice?", body: "Tap below to jump into the scenarios when they ship.")
            ]
        )
    }
}
