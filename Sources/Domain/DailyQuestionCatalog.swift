import Foundation

/// The authored Daily Questions. 30 days, roaming across archery / soccer /
/// basketball, no principle back-to-back. Each is counterintuitive but
/// explainable in one line — no math, no expert trivia.
///
/// Authored here as a Swift catalog (same pattern as the scenario catalogs).
/// When remote-config lands this becomes the bundled fallback.
enum DailyQuestionCatalog {

    static let all: [DailyQuestion] = [

        DailyQuestion(
            id: "dq-01", day: 1, sport: .archery, principle: "Trajectory shape",
            prompt: "You aim straight down the line at a distant gold and loose. On the way there, the arrow's path…",
            options: [
                "Drops below your line the whole way",
                "Rises above your line first, then falls back onto the gold",
                "Stays dead straight, then dips at the very end",
            ],
            answerIndex: 1,
            why: "To beat gravity the bow points slightly up, so the arrow arcs — climbing above your sight line before dropping back down onto the target.",
            funFact: "Two different distances get hit with the exact same aim — what shooters call \u{201C}point-blank\u{201D} range.",
            imageName: "dq-archery-twozero"
        ),

        DailyQuestion(
            id: "dq-02", day: 2, sport: .soccer, principle: "Magnus effect",
            prompt: "A free kick bends in mid-air. What actually pushes it sideways?",
            options: [
                "A gust of wind",
                "The spin dragging air around it",
                "The ball being slightly lopsided",
            ],
            answerIndex: 1,
            why: "Spin drags air faster on one side; the pressure difference shoves the ball toward the other — the Magnus effect.",
            funFact: "Roberto Carlos's 1997 free kick curved so much a ball-boy ducked.",
            imageName: "dq-soccer-magnus"
        ),

        DailyQuestion(
            id: "dq-03", day: 3, sport: .basketball, principle: "Shot arc",
            prompt: "Same shot, two arcs. Which gives the ball a bigger opening to drop through?",
            options: [
                "The flat, line-drive shot",
                "The high, soft arc",
                "They're identical",
            ],
            answerIndex: 1,
            why: "From straight above, the rim shows its full circle; a flat shot only \u{201C}sees\u{201D} a thin slot.",
            funFact: "Steph Curry's arc peaks around 11–12 ft — well above the 10 ft rim.",
            imageName: "dq-bball-arc"
        ),

        DailyQuestion(
            id: "dq-04", day: 4, sport: .archery, principle: "Shooting on a slope",
            prompt: "Same distance to the target, but now it's steeply uphill (or downhill). Compared to flat ground, the arrow drops…",
            options: [
                "More — so aim higher",
                "Less — so aim lower",
                "Exactly the same",
            ],
            answerIndex: 1,
            why: "Only the horizontal part of the distance lets gravity pull the arrow down, and a steep shot has less of it — so it falls less.",
            funFact: "Snipers call it the \u{201C}rifleman's rule\u{201D}; bowhunters in tree-stands live by it.",
            imageName: "dq-archery-incline"
        ),

        DailyQuestion(
            id: "dq-05", day: 5, sport: .soccer, principle: "Knuckleball",
            prompt: "A \u{201C}knuckleball\u{201D} is struck with almost no spin. Why does it wobble around unpredictably?",
            options: [
                "It's a lighter ball",
                "With no spin, the air wake flips side to side and shoves it",
                "The player mishit it",
            ],
            answerIndex: 1,
            why: "Spin stabilises a ball like a spinning top; with none, turbulence behind it swaps sides and nudges it erratically.",
            funFact: "The 2010 World Cup \u{201C}Jabulani\u{201D} knuckled so much keepers publicly complained.",
            imageName: "dq-soccer-knuckle"
        ),

        DailyQuestion(
            id: "dq-06", day: 6, sport: .basketball, principle: "Gravity & mass",
            prompt: "Drop a basketball and a tennis ball from the same height. Which hits the floor first?",
            options: [
                "The heavier basketball",
                "The lighter tennis ball",
                "They land together",
            ],
            answerIndex: 2,
            why: "Gravity speeds up everything at the same rate — mass doesn't change how fast it falls.",
            funFact: "An astronaut dropped a hammer and a feather on the Moon; they hit together.",
            imageName: "dq-bball-galileo"
        ),

        DailyQuestion(
            id: "dq-07", day: 7, sport: .archery, principle: "Archer's paradox",
            prompt: "The bow sits right in the arrow's path. How does a loosed arrow get around it and still fly straight?",
            options: [
                "It's nudged sideways at release",
                "It flexes and snakes around the bow",
                "There's a gap built into the bow",
            ],
            answerIndex: 1,
            why: "The shaft bends like a spring around the riser, wagging straight again in flight — the \u{201C}archer's paradox.\u{201D}",
            funFact: "Arrows are sold by \u{201C}spine\u{201D} — exactly how much they flex.",
            imageName: "dq-archery-paradox"
        ),

        DailyQuestion(
            id: "dq-08", day: 8, sport: .soccer, principle: "Air density",
            prompt: "The same curling free kick is taken at sea level and high in the mountains. In thin mountain air it…",
            options: [
                "Curves more",
                "Flies farther and straighter",
                "Behaves exactly the same",
            ],
            answerIndex: 1,
            why: "Less air means less drag and less sideways grip — so it travels farther but bends less.",
            funFact: "Strikers dread thin-air stadiums like Bogotá and La Paz for exactly this.",
            imageName: "dq-soccer-altitude"
        ),

        DailyQuestion(
            id: "dq-09", day: 9, sport: .basketball, principle: "Backspin",
            prompt: "Why do great shooters put backspin on the ball?",
            options: [
                "To make it look clean",
                "It softens the hit on the rim so it rolls in",
                "To make it go faster",
            ],
            answerIndex: 1,
            why: "Backspin kills energy on contact — the ball deadens against the rim instead of bouncing away (the \u{201C}shooter's roll\u{201D}).",
            funFact: "Ideal backspin is about 3 rotations on the way to the hoop.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-10", day: 10, sport: .archery, principle: "Distance vs drop",
            prompt: "A target twice as far away. The arrow drops about…",
            options: [
                "Twice as much",
                "Four times as much",
                "The same, just later",
            ],
            answerIndex: 1,
            why: "Drop grows with time squared, and double the distance takes double the time — so 2 × 2 = four times the fall.",
            funFact: "This same \u{201C}squared\u{201D} rule is why braking distance balloons at speed.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-11", day: 11, sport: .soccer, principle: "Reaction time",
            prompt: "A penalty is blasted from 11 m at ~100 km/h. How long does the keeper have to react and dive to the corner?",
            options: [
                "About 2 seconds",
                "About 1 second",
                "About 0.4 seconds",
            ],
            answerIndex: 2,
            why: "That's less than a human can see-decide-and-dive, so keepers have to guess early and commit.",
            funFact: "That's why so many keepers move before the ball is even struck.",
            imageName: "dq-soccer-penalty"
        ),

        DailyQuestion(
            id: "dq-12", day: 12, sport: .basketball, principle: "Hang time",
            prompt: "During a big dunk, where do you spend most of your \u{201C}hang time\u{201D}?",
            options: [
                "On the way up",
                "Near the very top",
                "On the way down",
            ],
            answerIndex: 1,
            why: "You slow to a stop at the peak, so you linger there — that's the \u{201C}hanging in the air\u{201D} illusion.",
            funFact: "Even Jordan's hang time was under a second — it just looked longer.",
            imageName: "dq-bball-hangtime"
        ),

        DailyQuestion(
            id: "dq-13", day: 13, sport: .archery, principle: "Fletching",
            prompt: "Why do arrows have feathers (fletching) at the back?",
            options: [
                "To make them lighter",
                "The tail-drag keeps the point facing forward",
                "Purely for looks",
            ],
            answerIndex: 1,
            why: "Drag at the rear keeps the heavy tip leading — and angled feathers spin it for extra stability.",
            funFact: "A fletchless arrow tumbles end-over-end within metres.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-14", day: 14, sport: .soccer, principle: "Topspin dip",
            prompt: "A rocket shot that suddenly dips down under the bar has…",
            options: [
                "Backspin",
                "Topspin",
                "No spin at all",
            ],
            answerIndex: 1,
            why: "Topspin makes the air push the ball down, dragging it under the bar faster than gravity alone.",
            funFact: "Cristiano Ronaldo's dipping efforts have topspin of ~7 rotations a second.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-15", day: 15, sport: .basketball, principle: "Bank shot",
            prompt: "Why does a bank shot off the backboard drop in?",
            options: [
                "The board is sticky",
                "The ball reflects off the glass like light off a mirror",
                "Luck, mostly",
            ],
            answerIndex: 1,
            why: "Hit the right spot and the bounce angle redirects the ball straight down into the rim — pure geometry.",
            funFact: "Studies show bank shots beat direct shots from the 45° \u{201C}wing\u{201D} angles.",
            imageName: "dq-bball-bank"
        ),

        DailyQuestion(
            id: "dq-16", day: 16, sport: .archery, principle: "Crosswind",
            prompt: "A steady crosswind blows left to right across the range. To still hit centre, you aim…",
            options: [
                "Into the wind, to the left",
                "With the wind, to the right",
                "Straight at the gold — wind cancels out",
            ],
            answerIndex: 0,
            why: "The wind pushes the arrow sideways the whole flight, so you start it upwind to let it drift back onto the gold.",
            funFact: "Top archers read the flags between every single shot.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-17", day: 17, sport: .soccer, principle: "Friction",
            prompt: "Why does the ball zip across a wet pitch faster?",
            options: [
                "The water pushes it",
                "Less friction — it skids instead of gripping",
                "It doesn't; that's a myth",
            ],
            answerIndex: 1,
            why: "A wet surface cuts the grip between ball and grass, so it loses less speed.",
            funFact: "Groundskeepers water the pitch pre-match to speed up the passing.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-18", day: 18, sport: .basketball, principle: "Energy loss",
            prompt: "A dropped basketball never bounces back to the same height. Where did that energy go?",
            options: [
                "Gravity ate it",
                "Lost as heat and sound on impact",
                "It's stored for the next bounce",
            ],
            answerIndex: 1,
            why: "Each squash-and-stretch wastes a bit of energy as warmth and that \u{201C}thud,\u{201D} so every bounce is lower.",
            funFact: "A good ball returns to about 75% of its drop height — a flat one, far less.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-19", day: 19, sport: .archery, principle: "Momentum",
            prompt: "On a gusty day, which arrow holds its line better?",
            options: [
                "The light, fast arrow",
                "The heavier arrow",
                "Weight makes no difference",
            ],
            answerIndex: 1,
            why: "More mass means more momentum, so the same wind nudges it off course less.",
            funFact: "Archers literally switch to heavier arrows when it's windy.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-20", day: 20, sport: .soccer, principle: "Why bend it",
            prompt: "With a clear shot, why would a player bend a free kick instead of blasting it straight?",
            options: [
                "It's harder to blast",
                "To curl it around the wall into a corner the keeper can't reach",
                "To slow it down",
            ],
            answerIndex: 1,
            why: "A straight ball is blocked by the wall; a curved one swerves around it into the open corner.",
            funFact: "Beckham built a whole career on this one trick.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-21", day: 21, sport: .basketball, principle: "Release point",
            prompt: "Pros release the jump shot at the top of their jump because…",
            options: [
                "It's higher up",
                "There they're momentarily still, so the shot is more repeatable",
                "The defender can't reach",
            ],
            answerIndex: 1,
            why: "At the peak your vertical speed is zero, so there's no up/down motion to throw off your aim.",
            funFact: "It's why a rushed \u{201C}on the way up\u{201D} shot so often clanks.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-22", day: 22, sport: .archery, principle: "Apex speed",
            prompt: "An arrow arcs high to a distant target. Where is it travelling slowest?",
            options: [
                "Right as it leaves the bow",
                "At the top of its arc",
                "Just before it hits",
            ],
            answerIndex: 1,
            why: "Climbing bleeds off its upward speed until, at the very top, only the forward part is left.",
            funFact: "It's moving fastest the instant it's loosed — then only loses speed.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-23", day: 23, sport: .soccer, principle: "Elastic energy",
            prompt: "A slightly deflated ball travels less far off the same kick. Why?",
            options: [
                "It's heavier",
                "It absorbs the kick's energy instead of springing back",
                "Air resistance doubles",
            ],
            answerIndex: 1,
            why: "A firm ball stores and snaps back the foot's energy; a soft one just squashes and soaks it up.",
            funFact: "Match balls are inflated to a tightly-regulated pressure for exactly this.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-24", day: 24, sport: .basketball, principle: "Optimal technique",
            prompt: "The \u{201C}granny-style\u{201D} underhand free throw looks silly — but it's actually…",
            options: [
                "A gimmick that never works",
                "One of the most accurate techniques there is",
                "Against the rules",
            ],
            answerIndex: 1,
            why: "It launches a high, soft arc with steady backspin and a simple repeatable motion — physically ideal.",
            funFact: "Rick Barry shot about 90% underhand; Wilt improved the moment he tried it.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-25", day: 25, sport: .archery, principle: "Spin stability",
            prompt: "Angled fletching makes the arrow spin in flight. What does the spin buy you?",
            options: [
                "More speed",
                "Stability — like a spinning top, it resists tipping",
                "A louder whistle",
            ],
            answerIndex: 1,
            why: "A spinning object holds its orientation, so small wobbles even out and the arrow flies true.",
            funFact: "Rifles spin their bullets for the very same reason.",
            imageName: "dq-archery-spin"
        ),

        DailyQuestion(
            id: "dq-26", day: 26, sport: .soccer, principle: "Backspin lift",
            prompt: "A delicate chip with backspin over the keeper…",
            options: [
                "Drops faster",
                "Floats and hangs a touch longer",
                "Curves left",
            ],
            answerIndex: 1,
            why: "Backspin gives a little lift, holding the ball up just long enough to drop behind the keeper.",
            funFact: "Messi and Pirlo's signature chips are all about this hang.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-27", day: 27, sport: .basketball, principle: "Range & arc",
            prompt: "A half-court buzzer-beater, compared to a free throw, needs…",
            options: [
                "A flatter, harder line drive",
                "More arc and more power",
                "Exactly the same shot, just stronger",
            ],
            answerIndex: 1,
            why: "To cover the distance and still drop into the rim, the ball has to be thrown both higher and harder.",
            funFact: "A half-court shot hangs in the air for roughly 2.5–3 seconds.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-28", day: 28, sport: .archery, principle: "Stored energy",
            prompt: "Olympic recurve bows curve their tips away from the archer. Why?",
            options: [
                "For style",
                "The shape stores and releases more energy into the arrow",
                "To make them shorter",
            ],
            answerIndex: 1,
            why: "The recurve geometry lets the limbs load up more energy and snap it into the arrow at release.",
            funFact: "\u{201C}Recurve\u{201D} is the official Olympic bow class — named for exactly this curve.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-29", day: 29, sport: .soccer, principle: "Spin vs none",
            prompt: "Two identical free kicks at the same speed — one spinning, one dead-still. Which is harder for the keeper?",
            options: [
                "The fast spinning one",
                "The dead-still knuckler",
                "They're equally easy",
            ],
            answerIndex: 1,
            why: "A spinning ball curves predictably; a spinless one wobbles late and randomly — impossible to read.",
            funFact: "Keepers say they'd rather face a swerving banana than a true knuckleball.",
            imageName: nil
        ),

        DailyQuestion(
            id: "dq-30", day: 30, sport: .basketball, principle: "Momentum",
            prompt: "A guard sprinting at full speed crashes into a defender who's planted and perfectly still. Who's more likely to hit the floor?",
            options: [
                "The defender who got hit",
                "The sprinting guard",
                "They both go down the same",
            ],
            answerIndex: 1,
            why: "The planted defender barely budges, so the guard's own forward momentum rebounds back into him — he's the one thrown off balance.",
            funFact: "That's the whole physics of \u{201C}taking a charge.\u{201D}",
            imageName: nil
        ),
    ]

    /// Look up a question by its stable id (e.g. "dq-03"). Used to restore the
    /// exact question a player answered today.
    static func question(withID id: String) -> DailyQuestion? {
        all.first { $0.id == id }
    }
}
