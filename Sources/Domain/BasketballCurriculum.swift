import Foundation

/// v2 basketball curriculum — 5 chapters, 3 scenarios each, authored from
/// BASKETBALL_JOURNEY.md v2 (2026-05-21).
///
/// Chapter sequence: Arc → Spin → Fade → Glass → Corner Three.
/// Each chapter ships a 6-card story lesson + 3 scenarios (easy / harder /
/// famous-moment anchor). Anchor scenarios use archetype-with-fingerprint
/// naming per §7 (era + team + signature, never the athlete's literal name).
///
/// Voice rules from §11 are enforced throughout: no "let's", third-person
/// not second, each lesson ends declarative, no academic concept names.
enum BasketballCurriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: "bb-ch1-arc",
            sport: .basketball,
            index: 1,
            title: "The arc",
            // Hybrid resolution: v3 mastery seeds + lensReveal kept (BranchP's
            // ch1 referenced `bb-freethrow-001`/`lesson_1_1` which aren't
            // authored — would break compilation/runtime). BranchP's new
            // `backgroundImageName` asset is adopted so ChapterView gets the
            // poster background BranchP introduced.
            subtitle: "Every shot is the same shape. Arc height controls everything.",
            lesson: lesson_1_arc,
            scenarioIDs: ["bb-1-baseline", "bb-1-flat", "bb-1-logo-three"],
            lensReveal: "Flat shots will look flat to you now.",
            levelTypeSeeds: [
                .findTheta: [
                    "bb-a-freethrow", "bb-a-elbow-r", "bb-a-top-key", "bb-a-logo",
                    "bb-a-wing-catch", "bb-a-tall-release", "bb-a-short-guard",
                    "bb-a-postup", "bb-a-half-court", "bb-a-tiptoe-corner",
                    "bb-a-ugly-1", "bb-a-ugly-2"
                ],
                .findV: [
                    "bb-b-freethrow", "bb-b-elbow", "bb-b-top-key", "bb-b-wing",
                    "bb-b-corner-3", "bb-b-rainbow", "bb-b-flat", "bb-b-logo",
                    "bb-b-stepback", "bb-b-floater", "bb-b-ugly-1", "bb-b-ugly-2"
                ],
                .findD: [
                    "bb-c-freethrow", "bb-c-elbow", "bb-c-wing-throw", "bb-c-flat-throw",
                    "bb-c-high-floater", "bb-c-rainbow", "bb-c-stepback-arc",
                    "bb-c-pull-up", "bb-c-half-court", "bb-c-ugly-1"
                ],
                // Level D content includes the 15 v2 scenarios. Per locked
                // spec §3.7 + §8 decision #9, all v2 anchors map here.
                .findBoth: [
                    "bb-1-baseline", "bb-1-flat", "bb-1-logo-three",
                    "bb-2-no-spin", "bb-2-shooters-roll", "bb-2-game-six-corner",
                    "bb-3-standstill", "bb-3-slight-fade", "bb-3-one-legged",
                    "bb-4-wing-bank", "bb-4-wrong-angle", "bb-4-elbow-bank",
                    "bb-5-toe-on-line", "bb-5-toe-behind", "bb-5-corner-pocket"
                ]
            ],
            backgroundImageName: "bb-ch1-bg"
        ),
        Chapter(
            id: "bb-ch2-spin",
            sport: .basketball,
            index: 2,
            title: "The spin",
            subtitle: "The shooter's roll is real. Backspin lifts and softens.",
            lesson: lesson_2_spin,
            scenarioIDs: ["bb-2-no-spin", "bb-2-shooters-roll", "bb-2-game-six-corner"],
            lensReveal: "When the announcer says 'good rotation,' you know what they see.",
            // v3: Ch 2-5 ship with Level D only until simulation gains spin/fade/bank.
            levelTypeSeeds: [:],
            backgroundImageName: "bb-ch2-bg"
        ),
        Chapter(
            id: "bb-ch3-fade",
            sport: .basketball,
            index: 3,
            title: "The fade",
            subtitle: "Your body's momentum becomes the ball's momentum.",
            lesson: lesson_3_fade,
            scenarioIDs: ["bb-3-standstill", "bb-3-slight-fade", "bb-3-one-legged"],
            lensReveal: "The body decides. The hand follows. Watch any jumper.",
            levelTypeSeeds: [:]
        ),
        Chapter(
            id: "bb-ch4-glass",
            sport: .basketball,
            index: 4,
            title: "The glass",
            subtitle: "The backboard square is geometry. The bank is the cheat.",
            lesson: lesson_4_glass,
            scenarioIDs: ["bb-4-wing-bank", "bb-4-wrong-angle", "bb-4-elbow-bank"],
            lensReveal: "The square is a target. You'll never un-see it.",
            levelTypeSeeds: [:]
        ),
        Chapter(
            id: "bb-ch5-corner",
            sport: .basketball,
            index: 5,
            title: "The corner three",
            subtitle: "A line on the floor changed how basketball is played.",
            lesson: lesson_5_corner,
            scenarioIDs: ["bb-5-toe-on-line", "bb-5-toe-behind", "bb-5-corner-pocket"],
            lensReveal: "The corner is the cheat code. You read modern basketball now.",
            levelTypeSeeds: [:]
        )
    ]

    /// Current basketball release: Ch 1 Level C (find d) practice. Wave 1
    /// adds three more authored seeds — two mid-range EASY situations and a
    /// short MEDIUM floater — all smoke-tested and ghost-arc-verified in CI.
    /// The broader seed pools remain authored above for diagnostics and
    /// future waves; normal navigation does not cycle through them yet.
    static let releasedPracticeSeedsByChapter: [String: [LevelTypeID: [String]]] = [
        "bb-ch1-arc": [
            .findD: [
                "bb-c-wing-throw",
                "bb-c-freethrow",
                "bb-c-elbow",
                "bb-c-high-floater"
            ]
        ]
    ]

    // MARK: - Lesson 1 — THE ARC
    //
    // Illustration slots bb-l1-01 … bb-l1-06 live in the asset catalog and
    // load by name. Until the art is added they resolve to nil and the cards
    // render type-only (LessonView guards with `if let uiImage`). Art direction
    // for each slot lives in Resources/Illustrations/lessons/README.md.

    private static let lesson_1_arc = LessonContent(
        id: "bb-l1-arc",
        title: "Why every shot is an arc",
        oneLiner: "Once it leaves the hand, only gravity acts on it.",
        estimatedReadSeconds: 70,
        cards: [
            .init(
                headline: "Every shot is the same shape.",
                body: "Once it leaves the hand, nothing changes it. Air doesn't push it. Nothing pulls it back. One thing remains.",
                illustration: "bb-l1-01"
            ),
            .init(
                headline: "Gravity.",
                body: "A constant pull, straight down. 9.8 meters per second per second. Same on every shot ever taken.",
                illustration: "bb-l1-02"
            ),
            .init(
                headline: "That's the whole story.",
                body: "Gravity plus the release. Two ingredients draw the arc.",
                illustration: "bb-l1-03"
            ),
            .init(
                headline: "And it has an equation.",
                body: "This is the rule the shot is obeying. Release height, angle, and speed — gravity does the rest.",
                illustration: "bb-l1-04",
                math: "y(t) = h + v · sin(θ) · t − ½ · g · t²"
            ),
            .init(
                headline: "Hang time is a myth.",
                body: "Jordan didn't hang. Gravity is constant. What looks like floating is the arc reaching its slowest point, then falling. The eye lies. The math doesn't.",
                illustration: "bb-l1-05"
            ),
            .init(
                headline: "The arc is already decided.",
                body: "The eye just hasn't caught it yet.",
                illustration: "bb-l1-06"
            )
        ]
    )

    // MARK: - Lesson 2 — THE SPIN

    private static let lesson_2_spin = LessonContent(
        id: "bb-l2-spin",
        title: "Why some shots stick",
        oneLiner: "Backspin softens the rim and lifts the ball.",
        estimatedReadSeconds: 75,
        cards: [
            .init(
                headline: "Why do some shots stick?",
                body: "That bounce on the rim — back iron, dies, drops. What is that?"
            ),
            .init(
                headline: "Backspin.",
                body: "When the ball rotates backward, the rim slows it. Energy gets absorbed instead of deflected. The shot finds the basket instead of leaving it."
            ),
            .init(
                headline: "Spin also lifts.",
                body: "A backspinning ball in flight gets a tiny upward nudge from the air. Soft hands give it just enough lift to land softer at the rim than a dead shot would."
            ),
            .init(
                headline: "The shooter's roll is real.",
                body: "Not luck. Not the basketball gods. Physics — that great shooters tune for without ever naming."
            ),
            .init(
                headline: "When the announcer says 'good rotation' —",
                body: "they're describing a measurable thing. You've been hearing it for years. Now you know what they're looking at."
            ),
            .init(
                headline: "No spin. Now spin. Watch."
            )
        ]
    )

    // MARK: - Lesson 3 — THE FADE

    private static let lesson_3_fade = LessonContent(
        id: "bb-l3-fade",
        title: "Why fadeaways are hard",
        oneLiner: "Your body's momentum becomes the ball's momentum.",
        estimatedReadSeconds: 80,
        cards: [
            .init(
                headline: "Why are fadeaways so hard?",
                body: "Even the best shooters miss them more than they make them."
            ),
            .init(
                headline: "You're moving backward.",
                body: "The body has velocity, away from the rim, at the moment of release."
            ),
            .init(
                headline: "The ball inherits it.",
                body: "Whatever the torso is doing at release, the ball joins. It's now moving slightly backward through the air."
            ),
            .init(
                headline: "So the arm overcompensates.",
                body: "More force, flatter release, different release point — all while the body is moving wrong."
            ),
            .init(
                headline: "Kobe shot fades at 38%.",
                body: "League average for contested fades: 29%. The mid-range artisans aren't just good. They're mechanical exceptions."
            ),
            .init(
                headline: "The body decides. The hand follows."
            )
        ]
    )

    // MARK: - Lesson 4 — THE GLASS

    private static let lesson_4_glass = LessonContent(
        id: "bb-l4-glass",
        title: "Why the square exists",
        oneLiner: "The backboard is a geometric cheat code.",
        estimatedReadSeconds: 70,
        cards: [
            .init(
                headline: "Nobody explains the square.",
                body: "It's been there since you started watching. Why?"
            ),
            .init(
                headline: "It's an aiming guide.",
                body: "Not decoration. The corners mark where the ball needs to hit for it to fall in."
            ),
            .init(
                headline: "Banks reflect predictably.",
                body: "Angle in equals angle out. The same rule as a billiard ball."
            ),
            .init(
                headline: "From the wing, this is huge.",
                body: "Direct shots from the 45° wing are mathematically hard. Banks turn that into a wide target."
            ),
            .init(
                headline: "Duncan's elbow bank.",
                body: "From the right elbow, banks were his highest-percentage shot. Not nostalgia. Geometry."
            ),
            .init(
                headline: "Now the angle."
            )
        ]
    )

    // MARK: - Lesson 5 — THE CORNER THREE

    private static let lesson_5_corner = LessonContent(
        id: "bb-l5-corner",
        title: "The line that changed basketball",
        oneLiner: "The corner three is the shortest three on the floor.",
        estimatedReadSeconds: 85,
        cards: [
            .init(
                headline: "Why does the line bend?",
                body: "The three-point arc is a perfect circle from center — except in the corners. There it goes straight. Why?"
            ),
            .init(
                headline: "Because the court isn't deep enough.",
                body: "A perfect arc would put the corner three at 23'9\". But the sideline is only 22 feet from the rim. So the line flattens."
            ),
            .init(
                headline: "That makes the corner shorter.",
                body: "22 feet vs. 23'9\" everywhere else. The corner is the shortest three on the floor."
            ),
            .init(
                headline: "A shorter shot is a better shot.",
                body: "Same release, same form, less distance. Higher percentage. More expected points per attempt."
            ),
            .init(
                headline: "Daryl Morey saw the math.",
                body: "Houston, the mid-2010s. They built an entire offense around corner threes and rim shots. Everyone else followed. The mid-range died."
            ),
            .init(
                headline: "One foot in. One foot out. Watch."
            )
        ]
    )
}
