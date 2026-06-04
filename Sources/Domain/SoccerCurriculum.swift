import Foundation

/// Soccer curriculum. Three Magnus-driven chapters — the curriculum
/// stays on a single physics concept (the sideways shove on a spinning
/// ball) and walks the player up the difficulty curve: open wall, then
/// closed-angle wall, then vertical-axis Magnus (the dip).
///
/// Design principle: every chapter reinforces the same Magnus rule,
/// only the geometry around it changes. The player builds one mental
/// model and applies it across three increasingly tight setups.
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
            id: "soc-ch2-crowding-wall",
            sport: .soccer,
            index: 2,
            title: "The crowding wall",
            subtitle: "The defenders step IN. The wall is in your face — the curl has to start wide.",
            lesson: lesson_2_wallUp,
            scenarioIDs: ["soc-curve-002"],
            lensReveal: "Tight angles will read open to you now."
        ),
        Chapter(
            id: "soc-ch3-header",
            sport: .soccer,
            index: 3,
            title: "The header",
            subtitle: "Don't shoot AT the goal. Curl the ball onto a teammate's head — the head does the angle.",
            lesson: lesson_3_header,
            scenarioIDs: ["soc-header-001"],
            lensReveal: "Every set-piece header you watch will read different now."
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

    // MARK: - Lesson 2 — "The crowding wall" as a 5-card story
    //
    // Magnus stays the same; the wall encroaches on the kicker. The
    // lesson points the player at the two levers Magnus exposes — SPIN
    // and POWER — and reminds them that the new power-scaling means a
    // harder kick now curls more, not less.

    private static let lesson_2_wallUp = LessonContent(
        id: "soc-l2.1-crowding-wall",
        title: "Why a wall in your face changes everything",
        oneLiner: "The wall stepped IN. Magnus didn't change — but you lost the runway in front of the curl.",
        estimatedReadSeconds: 85,
        cards: [
            // Card 1 — hook: the wall closed in on the kicker
            .init(
                headline: "The wall stepped INTO the kick.",
                body: "Same boot. Same ball. But the defenders are no longer 9 metres out — they've crept toward YOU. From the spot, the wall fills almost the whole opening before the ball has even started to bend.",
                illustration: "soc-l2-01"
            ),
            // Card 2 — same physics, less runway BEFORE the wall
            .init(
                headline: "Same rule. Less runway.",
                body: "Magnus hasn't changed. One side of the ball still cuts, the other still drags, the air still shoves it sideways. What changed is how MUCH of that shove happens BEFORE the wall — and that part is now almost nothing.",
                illustration: "soc-l2-02"
            ),
            // Card 3 — the two real levers
            .init(
                headline: "Two dials. SPIN and POWER.",
                body: "Crank up SPIN and the air gets a bigger lever on the ball. Crank up POWER and the boot brushes more spin AND drives faster airflow — both compound into a bigger curl.",
                illustration: "soc-l2-03",
                math: "curve  ∝  spin · power"
            ),
            // Card 4 — practical move
            .init(
                headline: "Start wide. Finish inside.",
                body: "Don't aim at the corner — aim PAST the wall on the spin's side. The curl will do the long work behind the wall, between the wall and the goal. The closer the wall sits to you, the wider you have to start.",
                illustration: "soc-l2-04"
            ),
            // Card 5 — close the loop
            .init(
                headline: "Now you call it.",
                body: "A wall almost in the kicker's face. A ball spinning hard. The boot is set. Where does the curl land?",
                illustration: "soc-l2-05"
            )
        ]
    )

    // MARK: - Lesson 3 — "The header" as a 5-card story
    //
    // Magnus stays the engine: the player uses the same curl they
    // learned in Ch1/Ch2, but the TARGET changes. Instead of bending
    // the ball into the goal, they bend it onto a teammate's head —
    // and the head provides the second angle change the defenders
    // can't account for.

    private static let lesson_3_header = LessonContent(
        id: "soc-l3.1-header",
        title: "Why a head turns a closed angle into an open one",
        oneLiner: "Magnus delivers the ball. The head delivers the goal.",
        estimatedReadSeconds: 95,
        cards: [
            // Card 1 — hook: the direct line is dead, the box is alive
            .init(
                headline: "The shot is closed. The BOX isn't.",
                body: "A wall in front. A keeper behind. The direct lane to goal is sealed. But the six-yard box is open — and a teammate is ghosting in.",
                illustration: "soc-l3-01"
            ),
            // Card 2 — heads change the angle
            .init(
                headline: "A head is a second boot.",
                body: "A header isn't a touch — it's a NEW launch. The ball arrives at one angle; the head sends it off at another. The keeper sets up for the angle you're not taking anymore.",
                illustration: "soc-l3-02"
            ),
            // Card 3 — Magnus delivers the cross
            .init(
                headline: "Same Magnus. New target.",
                body: "The curl you used to bend a ball into the corner can also drop one onto a teammate's forehead. Same physics — pick a point in space, spin the ball, the air finishes the line.",
                illustration: "soc-l3-03",
                math: "curve  ∝  spin · power"
            ),
            // Card 4 — practical move
            .init(
                headline: "Aim AT the head, not at the goal.",
                body: "Stop thinking about the corner. The corner is the teammate's problem now. Your job is to put the ball onto their head — let the redirect do the geometry the wall is denying you.",
                illustration: "soc-l3-04"
            ),
            // Card 5 — close the loop
            .init(
                headline: "Now you call it.",
                body: "A teammate in the six. A wall in front. The boot is set to curl the ball onto a head — and the head is set to nod it home. Does it find the corner?",
                illustration: "soc-l3-05"
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
