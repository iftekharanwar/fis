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
            scenarioIDs: ["arc-pingap-001"],
            backgroundImageName: "arc-ch1-bg"
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

    // MARK: - Lesson 1.1 — "The pin gap" as a 6-card story

    private static let lesson_1_1 = LessonContent(
        id: "arc-l1.1-pingap",
        title: "Why an arrow drops more than you think",
        oneLiner: "Same gravity as a free throw. A quarter-second of flight — and the drop quadruples when you double the range.",
        estimatedReadSeconds: 75,
        cards: [
            // Card 1 — set the hook
            .init(
                headline: "An arrow drops, too.",
                body: "Watch a free throw and you see the arc. Watch an arrow — you don't. It's too fast. But the arc is still there."
            ),
            // Card 2 — name the force
            .init(
                headline: "Same gravity. 9.8 m/s².",
                body: "The arrow obeys the same rule as the basketball. It just travels so fast that a quarter-second is the entire flight."
            ),
            // Card 3 — the key insight
            .init(
                headline: "Drop scales with time SQUARED.",
                body: "Twice the distance isn't twice the drop. It's four times. Gravity gets longer to pull — and time multiplies on itself.",
                math: "Δy = ½ · g · t²"
            ),
            // Card 4 — name the pin
            .init(
                headline: "Your sight pin is a guess about distance.",
                body: "A pin is calibrated for one yardage. At that distance, it puts the arrow in the bullseye. At any other distance, it lies."
            ),
            // Card 5 — the practical move
            .init(
                headline: "Holdover.",
                body: "To hit farther with a closer-calibrated pin, aim ABOVE the bullseye. The longer the shot, the higher you hold."
            ),
            // Card 6 — close the loop
            .init(
                headline: "Now you call it.",
                body: "A 40m bullseye. A 20m pin. The pin looks dead-on. Where does the arrow actually land?"
            )
        ]
    )

    // MARK: - Lesson 2.1 — "The archer's paradox" as a 6-card story

    private static let lesson_2_1 = LessonContent(
        id: "arc-l2.1-paradox",
        title: "Why arrows bend through the bow",
        oneLiner: "The shaft is resting against the bow. To get out, it has to flex around it — and the stiffness has to be right.",
        estimatedReadSeconds: 90,
        cards: [
            // Card 1 — set the hook
            .init(
                headline: "Arrows aren't sticks. They're springs.",
                body: "Watch a slow-motion shot. The shaft is bent like a bow itself — wobbling visibly as it leaves the string. That's not a mistake. It HAS to bend."
            ),
            // Card 2 — name the geometry
            .init(
                headline: "The string is behind. The arrow rests on the side.",
                body: "The shaft sits against the riser — the front of the bow. When the string snaps forward, it pushes the back of the arrow. But the shaft has nowhere straight to go: the riser is in the way."
            ),
            // Card 3 — the bend
            .init(
                headline: "So the arrow flexes around it.",
                body: "It bends in the middle, slips past the riser, then springs back. The whole thing happens in milliseconds — but it's visible on slow-motion video."
            ),
            // Card 4 — spine
            .init(
                headline: "Spine = the arrow's stiffness.",
                body: "Match it to your bow's draw weight and the flex is just right: arrow clears the riser, snaps back straight, hits clean. Too stiff or too soft — the arrow wobbles all the way to the target."
            ),
            // Card 5 — practical consequence
            .init(
                headline: "Mismatch = miss.",
                body: "A 60-lb bow needs a stiffer arrow than a 40-lb bow. Cross them up and the arrow oscillates through the entire flight, impacting at an angle and burying off-target."
            ),
            // Card 6 — close the loop
            .init(
                headline: "Now you call it.",
                body: "A 60-lb bow. An 85-spine arrow. Watch the release in slow-motion and tell me — will it fly clean?"
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
