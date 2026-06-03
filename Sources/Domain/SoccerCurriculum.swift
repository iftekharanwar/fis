import Foundation

/// Soccer curriculum. Five chapters, each teaching one Magnus-driven
/// counterintuition real strikers learn the hard way. Chapter 1 ships
/// with a fully authored lesson; chapters 2–5 are scaffolded so the
/// ladder is visible on the chapter list while content is in authoring.
///
/// Design principle: each chapter introduces a new spin behaviour. The
/// player picks up a fresh physics mechanic on every free kick — first
/// the side-spin curve, then topspin dip, then the spin-less knuckle,
/// then heavy banana spin from a wide angle, then the corner-flag arc.
enum SoccerCurriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: "soc-ch1-curve",
            sport: .soccer,
            index: 1,
            title: "The curve",
            subtitle: "The ball doesn't travel in a straight line. Side spin curls it around the wall.",
            lesson: lesson_1_curve,
            scenarioIDs: ["soc-curve-001"],
            lensReveal: "Every banana shot has the same secret now."
        ),
        Chapter(
            id: "soc-ch2-dip",
            sport: .soccer,
            index: 2,
            title: "The dip",
            subtitle: "Topspin doesn't push the ball sideways. It pushes it down — hard.",
            lesson: scaffold(
                id: "soc-l2.1-dip",
                title: "Why a struck shot drops under the bar",
                oneLiner: "The top of the ball drags through the air; the air shoves the ball into the ground.",
                seconds: 90
            ),
            scenarioIDs: ["soc-dip-001"],
            lensReveal: "When a striker drops one over the keeper, you'll see why."
        ),
        Chapter(
            id: "soc-ch3-knuckle",
            sport: .soccer,
            index: 3,
            title: "The knuckle",
            subtitle: "No spin means no Magnus force — and the ball wobbles unpredictably.",
            lesson: scaffold(
                id: "soc-l3.1-knuckle",
                title: "Why a clean strike fools the keeper",
                oneLiner: "With no rotation, the airflow flips chaotically and the ball lurches sideways late.",
                seconds: 95
            ),
            scenarioIDs: ["soc-knuckle-001"],
            lensReveal: "You'll spot a knuckler before the keeper does."
        ),
        Chapter(
            id: "soc-ch4-banana",
            sport: .soccer,
            index: 4,
            title: "The banana",
            subtitle: "From a wide angle the goal looks closed — until the curve bends it open.",
            lesson: scaffold(
                id: "soc-l4.1-banana",
                title: "Why a heavy side spin can reach the far corner",
                oneLiner: "Maximum side spin pulls the flight into a long arc — the keeper steps the wrong way.",
                seconds: 105
            ),
            scenarioIDs: ["soc-banana-001"],
            lensReveal: "From now on, no angle looks closed to you."
        ),
        Chapter(
            id: "soc-ch5-olympic",
            sport: .soccer,
            index: 5,
            title: "The olympic",
            subtitle: "A goal scored direct from a corner kick. Pure Magnus, no touch needed.",
            lesson: scaffold(
                id: "soc-l5.1-olympic",
                title: "Why a corner can curl all the way in",
                oneLiner: "From a 90-degree angle, only an inswinging spin can carry the ball into the net.",
                seconds: 110
            ),
            scenarioIDs: ["soc-olympic-001"],
            lensReveal: "The Olympic goal isn't luck. It's geometry."
        )
    ]

    // MARK: - Lesson 1.1 — "The curve" as a 7-card story
    //
    // Mirrors the archery Ch1 story shape: hook → physics → law → numbers
    // → mechanism → application → scenario lead-in. Illustration slots
    // soc-l1-01 … soc-l1-07 are referenced by name and resolve to nil
    // until the art is added (LessonView guards with `if let uiImage`).

    private static let lesson_1_curve = LessonContent(
        id: "soc-l1.1-curve",
        title: "Why a struck ball curves",
        oneLiner: "Spin the ball, and the air picks a side. The same wind that holds an airplane up bends a free kick around a wall.",
        estimatedReadSeconds: 100,
        cards: [
            // Card 1 — hook: the impossible bend
            .init(
                headline: "The ball turns in mid-air.",
                body: "A free kick leaves the foot heading one way, and ends up somewhere else entirely. No wind. No touch. The path bends on its own.",
                illustration: "soc-l1-01"
            ),
            // Card 2 — the cause: spin
            .init(
                headline: "It's spinning.",
                body: "Strike the ball off-centre and it rotates as it flies. The whole ball is turning around an axis the eye never quite catches — but the air does.",
                illustration: "soc-l1-02"
            ),
            // Card 3 — the rule (Magnus, named in sport vocab)
            .init(
                headline: "One side cuts. The other drags.",
                body: "On a spinning ball, one side moves WITH the airflow and one side moves AGAINST it. The cutting side slips; the dragging side pushes back. The pressure difference shoves the ball sideways.",
                illustration: "soc-l1-03",
                math: "F ∝ ω × v"
            ),
            // Card 4 — the law in numbers
            .init(
                headline: "A few revs per second is enough.",
                body: "At ten rotations a second — the rate of a well-struck free kick — the sideways shove is around a tenth of gravity. Over 25 meters of flight, that's two to three meters of bend.",
                illustration: "soc-l1-04",
                math: "25 m flight  →  ≈ 2.5 m curve"
            ),
            // Card 5 — same physics as a wing
            .init(
                headline: "Same rule that holds airplanes up.",
                body: "A wing splits the airflow above and below. A spinning ball splits the airflow left and right. The lift is sideways instead of upward — but the air doesn't know the difference.",
                illustration: "soc-l1-05"
            ),
            // Card 6 — the practical move
            .init(
                headline: "Aim where it isn't going.",
                body: "The wall blocks the straight line. So don't shoot the straight line. Aim past the wall, on the side the spin will pull from, and let the curve bring it home.",
                illustration: "soc-l1-06"
            ),
            // Card 7 — close the loop into the scenario
            .init(
                headline: "Now you call it.",
                body: "A wall of three defenders. A ball spinning hard around a vertical axis. The foot points to the left of the post — and the air is about to make a decision. Where does it land?",
                illustration: "soc-l1-07"
            )
        ]
    )

    // MARK: - Scaffold helper

    /// Placeholder for chapters whose lessons aren't fully authored yet.
    /// Three cards minimum so the story shape still reads while content
    /// is in authoring — same shape as the archery scaffold.
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
                .init(headline: "Ready to read the curve?", body: "Tap below to jump into the scenario.")
            ]
        )
    }
}
