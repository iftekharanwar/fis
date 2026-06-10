import Foundation

/// Formula 1 curriculum — a ten-chapter "book" on the physics of driving at
/// the limit. Two acts: Act I is the mechanical car (grip, geometry, energy,
/// load); Act II is the aerodynamic car (the air). Each act closes on an
/// integration chapter that braids the prior concepts together —
/// Ch 5 "The corner" (every Act-I idea in one move) and Ch 10 "The lap"
/// (the whole book in one flying lap).
///
/// Unlike every other sport in the app, F1 isn't projectile motion — it's
/// centripetal force and friction. Chapter 1 (`v = √(μ·g·r)`) is the
/// foundation everything else builds on, the same way archery's Ch 1
/// projectile drop anchors its ladder.
///
/// Chapter 1 ships with a fully authored 9-card lesson; chapters 2–10 are
/// scaffolded so the book's arc is visible on the chapter list while the
/// copy is in authoring. Only Ch 1 carries a scenario today — the playable
/// corner lands in the next pass.
enum F1Curriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: "f1-ch1-limit",
            sport: .formula1,
            index: 1,
            title: "The limit",
            subtitle: "Horsepower gets you to the corner. Grip decides whether you make it through.",
            lesson: lesson_1_1,
            scenarioIDs: ["f1-limit-001"]
        ),
        Chapter(
            id: "f1-ch2-line",
            sport: .formula1,
            index: 2,
            title: "The line",
            subtitle: "The shortest way round is the slowest. Straighten the corner and you carry more speed.",
            lesson: scaffold(
                id: "f1-l2.1-line",
                title: "Why the wide line is the fast line",
                oneLiner: "The fastest path isn't the shortest — the wide line is a bigger radius, and a bigger radius raises the limit.",
                seconds: 90
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch3-brakezone",
            sport: .formula1,
            index: 3,
            title: "The brake zone",
            subtitle: "Twice the speed needs four times the room to stop. The lap is won on the brakes.",
            lesson: scaffold(
                id: "f1-l3.1-brakezone",
                title: "Why stopping distance grows with the square of speed",
                oneLiner: "Stopping distance grows with the square of speed — kinetic energy is ½·m·v².",
                seconds: 95
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch4-weight",
            sport: .formula1,
            index: 4,
            title: "Weight transfer",
            subtitle: "Grip follows weight. Brake and the front bites; get on the power and it lets go.",
            lesson: scaffold(
                id: "f1-l4.1-weight",
                title: "Why the car's balance moves as you drive it",
                oneLiner: "Grip is proportional to load — and load shifts the instant you brake or accelerate.",
                seconds: 100
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch5-corner",
            sport: .formula1,
            index: 5,
            title: "The corner",
            subtitle: "Brake, turn, and balance at once — trade braking grip for cornering grip without ever leaving the limit.",
            lesson: scaffold(
                id: "f1-l5.1-corner",
                title: "Trail braking: chapters 1–4 in a single corner",
                oneLiner: "Ride the friction circle from braking into the turn — the first integration of everything so far.",
                seconds: 110
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch6-downforce",
            sport: .formula1,
            index: 6,
            title: "Downforce",
            subtitle: "Speed makes its own grip. The faster you go, the harder the car is pressed into the road.",
            lesson: scaffold(
                id: "f1-l6.1-downforce",
                title: "Why a fast corner has more grip than a slow one",
                oneLiner: "Aerodynamic downforce scales with v², so the limit itself rises with speed.",
                seconds: 95
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch7-drag",
            sport: .formula1,
            index: 7,
            title: "Drag",
            subtitle: "Downforce isn't free. The same wings that hold the corner cap your top speed.",
            lesson: scaffold(
                id: "f1-l7.1-drag",
                title: "Why every wing setting is a trade",
                oneLiner: "Drag also scales with v²; top speed is where the engine's push equals the air's pull.",
                seconds: 90
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch8-tow",
            sport: .formula1,
            index: 8,
            title: "The tow",
            subtitle: "The air a car leaves behind both helps and hurts — free speed on the straight, lost grip in the corner.",
            lesson: scaffold(
                id: "f1-l8.1-tow",
                title: "Why you hide in a slipstream — and pay for it in the corners",
                oneLiner: "A slipstream cuts drag for the car behind, but its dirty air steals downforce when you turn.",
                seconds: 100
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch9-window",
            sport: .formula1,
            index: 9,
            title: "The window",
            subtitle: "Grip isn't a constant. Tyres only bite in a narrow heat window — and it closes as they wear.",
            lesson: scaffold(
                id: "f1-l9.1-window",
                title: "Why grip comes and goes over a stint",
                oneLiner: "The grip coefficient μ depends on tyre temperature — there's a window, and a cliff.",
                seconds: 105
            ),
            scenarioIDs: []
        ),
        Chapter(
            id: "f1-ch10-lap",
            sport: .formula1,
            index: 10,
            title: "The lap",
            subtitle: "One flying lap. Every idea in the book at once, with nothing left in reserve.",
            lesson: scaffold(
                id: "f1-l10.1-lap",
                title: "The flying lap: the whole book in ninety seconds",
                oneLiner: "One qualifying lap that demands every concept in the book at once — the grand integration.",
                seconds: 120
            ),
            scenarioIDs: []
        )
    ]

    // MARK: - Lesson 1.1 — "The limit" as a 9-card story
    //
    // Illustration slots f1-l1-01 … f1-l1-09 live in the asset catalog and
    // load by name. Until the art is added they resolve to nil and the cards
    // render type-only (LessonView guards with `if let uiImage`).

    private static let lesson_1_1 = LessonContent(
        id: "f1-l1.1-limit",
        title: "Why a corner has a speed limit",
        oneLiner: "The engine gets you to the corner; grip decides the rest. Every bend has one true speed — and four times the appetite when you double it.",
        estimatedReadSeconds: 100,
        cards: [
            // Card 1 — hook: power owns the straight, not the corner
            .init(
                headline: "Horsepower gets you TO the corner. Not through it.",
                body: "On the straight, power is everything. But the moment the road bends, the engine goes quiet in the math — what happens next is decided by something else entirely.",
                illustration: "f1-l1-01"
            ),
            // Card 2 — name the force: cornering is centripetal
            .init(
                headline: "Turning is just falling sideways.",
                body: "To follow a curve, the car has to be pulled toward the inside the whole way around — a constant tug off its straight-line path. That pull has exactly one source: the tyres gripping the road.",
                illustration: "f1-l1-02"
            ),
            // Card 3 — the grip budget / friction circle
            .init(
                headline: "A tyre has ONE grip budget.",
                body: "Braking, accelerating, turning — every one spends from the same account. Use it all to turn and there's nothing left to brake. Use it all to brake and you can't turn. That trade-off is the friction circle.",
                illustration: "f1-l1-03",
                math: "a ≤ μ · g"
            ),
            // Card 4 — the demand grows with the square of speed
            .init(
                headline: "Faster corner, harder pull — and it squares.",
                body: "The grip a corner demands climbs with the square of speed. Take the same bend twice as fast and it asks for four times the grip. Speed gets expensive in a hurry.",
                illustration: "f1-l1-04",
                math: "a = v² / r"
            ),
            // Card 5 — myth-bust: past the limit, grip just runs out (the MISS image)
            .init(
                headline: "Ask for more than the tyre has, and it lets go.",
                body: "Past the limit there's no drama, no spin — the front just stops biting. The car runs wide while you turn the wheel into empty air. That's understeer, and it's grip simply running out.",
                illustration: "f1-l1-05"
            ),
            // Card 6 — the equation: one corner, one speed
            .init(
                headline: "v = √(μ · g · r).",
                body: "Grip, gravity, and the corner's radius hand you a single top speed. It isn't a suggestion and it isn't about bravery — go faster than this and the physics says no.",
                illustration: "f1-l1-06",
                math: "v_max = √(μ · g · r)"
            ),
            // Card 7 — concrete numbers, so the law isn't hand-wavy
            .init(
                headline: "A tight hairpin: about 80 km/h. That's all.",
                body: "Put real numbers in. On slick tyres a 30-metre hairpin tops out near 75 km/h; open the radius to 100 metres and the same grip carries 140. The corner's size sets the speed.",
                illustration: "f1-l1-07",
                math: "r = 30 m   →  ≈ 75 km/h\nr = 100 m  →  ≈ 140 km/h"
            ),
            // Card 8 — payoff + tease: the two ways past the limit (Ch2, Ch6)
            .init(
                headline: "So how do they go faster? Two ways.",
                body: "You can't out-throttle the limit — but you can move it. Make the radius bigger by changing your path through the corner (the LINE, next). Or make more grip appear out of thin air (DOWNFORCE, later). The rest of the book is those two ideas.",
                illustration: "f1-l1-08"
            ),
            // Card 9 — close the loop into the scenario
            .init(
                headline: "Now you call it.",
                body: "A fifty-metre corner. Dry slicks. The driver commits and turns in. You know the limit is real now — so does the car find the apex, or wash wide?",
                illustration: "f1-l1-09"
            )
        ]
    )

    // MARK: - Scaffold helper

    /// Placeholder for chapters whose lessons aren't authored yet. Three cards
    /// minimum so the story shape still reads while content is pending.
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
