import Foundation

/// Archery curriculum. Five chapters, each teaching one counterintuition
/// real archers learn the hard way. Chapter 1 ships with a fully authored
/// 6-card lesson; chapters 2–5 are scaffolded so the ladder is visible
/// on the chapter list while content is in authoring.
///
/// Design principle: every chapter has to break a different piece of naive
/// "the arrow goes where I aim" intuition. Pure projectile motion (Ch 1)
/// is the foundation that everything else builds on.
enum ArcheryCurriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: "arc-ch1-pingap",
            sport: .archery,
            index: 1,
            title: "The pin gap",
            subtitle: "The arrow falls. Your sight only knows one distance.",
            lesson: lesson_1_1,
            scenarioIDs: ["arc-pingap-001"]
        ),
        Chapter(
            id: "arc-ch2-paradox",
            sport: .archery,
            index: 2,
            title: "The archer's paradox",
            subtitle: "The arrow leaves from the side of the bow — yet hits dead center. Why?",
            lesson: lesson_2_1,
            scenarioIDs: ["arc-paradox-001"]
        ),
        Chapter(
            id: "arc-ch3-wind",
            sport: .archery,
            index: 3,
            title: "Wind accumulates",
            subtitle: "Crosswind doesn't shove your arrow. It drifts it — and the drift grows with distance.",
            lesson: scaffold(
                id: "arc-l3.1-drift",
                title: "Why a steady wind costs more at longer range",
                oneLiner: "Lateral drift scales with time-in-flight squared, not distance.",
                seconds: 90
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "arc-ch4-rifleman",
            sport: .archery,
            index: 4,
            title: "Rifleman's rule",
            subtitle: "Shooting steeply downhill, the arrow flies HIGH — not low. Most archers get it backwards.",
            lesson: scaffold(
                id: "arc-l4.1-angled",
                title: "Why gravity cares about horizontal distance, not slant",
                oneLiner: "Aim at the horizontal projection — not the line-of-sight distance.",
                seconds: 105
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "arc-ch5-mass",
            sport: .archery,
            index: 5,
            title: "Heavy flies slow, but straight",
            subtitle: "A heavier arrow drops more, but the wind moves it less. There is no free lunch.",
            lesson: scaffold(
                id: "arc-l5.1-mass",
                title: "Why arrow mass is a tradeoff between drop and drift",
                oneLiner: "Same bow energy, different mass — the physics splits the bill.",
                seconds: 120
            ),
            scenarioIDs: []
        )
    ]

    // MARK: - Lesson 1.1 — "The pin gap" as an 8-card story
    //
    // Illustration slots arc-l1-01 … arc-l1-08 live in the asset catalog and
    // load by name. Until the art is added they resolve to nil and the cards
    // render type-only (LessonView guards with `if let uiImage`).

    private static let lesson_1_1 = LessonContent(
        id: "arc-l1.1-pingap",
        title: "Why an arrow drops more than you think",
        oneLiner: "Same gravity as a free throw. A blink of flight — yet doubling the range quadruples the drop.",
        estimatedReadSeconds: 90,
        cards: [
            // Card 1 — hook: the arc is there, just hidden
            .init(
                headline: "An arrow falls, too.",
                body: "A free throw shows its arc. An arrow hides it — the flight is a blink. But gravity pulls on it the entire way, start to finish.",
                illustration: "arc-l1-01"
            ),
            // Card 2 — same force as everything else
            .init(
                headline: "Same gravity. 9.8 m/s².",
                body: "The arrow obeys the exact rule a dropped ball does. The only difference is speed: the whole trip is over in a fraction of a second.",
                illustration: "arc-l1-02"
            ),
            // Card 3 — the squared law (core counterintuition)
            .init(
                headline: "Double the distance. Quadruple the drop.",
                body: "Drop grows with the square of flight time, and time grows with distance. So 40 m doesn't sag twice as much as 20 m — it sags four times as much.",
                illustration: "arc-l1-03",
                math: "Δy = ½ · g · t²"
            ),
            // Card 4 — concrete numbers, so the law isn't hand-wavy
            .init(
                headline: "Half a meter at 20. Over two at 40.",
                body: "A recurve arrow leaves near 60 m/s. At 20 m it flies about a third of a second and drops roughly half a meter. At 40 m the drop climbs past two — more than a body length lower.",
                illustration: "arc-l1-04",
                math: "20 m  →  ≈ 0.5 m\n40 m  →  ≈ 2.2 m"
            ),
            // Card 5 — a pin is calibrated for exactly one range
            .init(
                headline: "Your sight pin knows ONE distance.",
                body: "Sight a pin in at 20 m and it's perfect — there. The pin locks the bow's launch angle for that one range. Anywhere else, that angle is already wrong.",
                illustration: "arc-l1-05"
            ),
            // Card 6 — the chapter's namesake: gaps grow with range
            .init(
                headline: "So the pins bunch up close, spread out far.",
                body: "On a multi-pin sight the 20 and 30 sit almost together. The 40, 50, 60 pins spread wider and wider — each added step of distance adds more drop than the last. The gap IS the squared law, made visible.",
                illustration: "arc-l1-06"
            ),
            // Card 7 — the practical move
            .init(
                headline: "Past your pin? Hold over.",
                body: "With one pin sighted short, a longer shot needs it held ABOVE the gold — let the extra drop carry the arrow down into center. The farther out, the higher you hold.",
                illustration: "arc-l1-07"
            ),
            // Card 8 — close the loop into the scenario
            .init(
                headline: "Now you call it.",
                body: "A target at 40 meters. A pin sighted for 20. The pin sits dead on the gold — and now you know it's lying. Where does the arrow actually land?",
                illustration: "arc-l1-08"
            )
        ]
    )

    // MARK: - Lesson 2.1 — "The archer's paradox" as a 7-card story
    //
    // Illustration slots arc-l2-01 … arc-l2-07. Cards 02 (flex wave) and 05
    // (spine deflection test) ship as code-generated diagrams; the rest load
    // by name once added (LessonView guards with `if let uiImage`).

    private static let lesson_2_1 = LessonContent(
        id: "arc-l2.1-paradox",
        title: "Why arrows bend through the bow",
        oneLiner: "The shaft rests against the bow. To escape, it has to flex around the handle — and the stiffness has to match the draw.",
        estimatedReadSeconds: 100,
        cards: [
            // Card 1 — the paradox itself (the hook)
            .init(
                headline: "It points off the gold — and hits it anyway.",
                body: "At full draw the arrow rests against the side of the bow, angled a little off the line to the target. By straight-line logic it should miss. For centuries, no one could say why it doesn't.",
                illustration: "arc-l2-01"
            ),
            // Card 2 — arrows are springs
            .init(
                headline: "An arrow is a spring, not a rod.",
                body: "High-speed film settled it. Leaving the string, the shaft bends and wobbles, flexing side to side like a struck tuning fork. That bending isn't a flaw — it's the whole trick.",
                illustration: "arc-l2-02"
            ),
            // Card 3 — why it must bend
            .init(
                headline: "The push comes from behind — into the bow.",
                body: "The string drives the back of the shaft straight forward. But the riser — the bow's handle — sits right in the path. With nowhere straight to go, the arrow has to bend around it.",
                illustration: "arc-l2-03"
            ),
            // Card 4 — flex around, recover straight
            .init(
                headline: "It snakes past the handle, then recovers straight.",
                body: "The shaft's middle bows out to clear the riser, whips back the other way, then settles straight — all in a few thousandths of a second. The flex is only a few percent of the shaft's length, but on high-speed film it's unmistakable.",
                illustration: "arc-l2-04"
            ),
            // Card 5 — spine = stiffness
            .init(
                headline: "Spine is how far an arrow bends.",
                body: "Hang a set weight from the middle of a supported shaft and measure the sag — that's spine. A stiff arrow barely flexes; a weak one bends far. Every shaft is rated for a band of bow weights.",
                illustration: "arc-l2-05"
            ),
            // Card 6 — match / mismatch
            .init(
                headline: "Too stiff or too soft, and it never recovers.",
                body: "A heavier bow throws harder, so it needs a stiffer arrow. Off the match, the flex is wrong: the shaft fishtails the whole way and slaps in at an angle. Spine has to fit the bow.",
                illustration: "arc-l2-06"
            ),
            // Card 7 — close the loop into the scenario (60 lb bow, 85 spine)
            .init(
                headline: "Now you call it.",
                body: "A 60-pound bow. An 85-spine shaft — stiffer than the bow is asking for. Watch the release in slow motion: does it recover, or wobble off the gold?",
                illustration: "arc-l2-07"
            )
        ]
    )

    // MARK: - Scaffold helper

    /// Placeholder for chapters whose lessons aren't authored yet. Three
    /// cards minimum so the story shape still reads while content is pending.
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
