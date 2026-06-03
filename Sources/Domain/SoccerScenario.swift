import Foundation

/// A single soccer free-kick scenario — enough state to render the scene
/// (shooter, wall, goalkeeper, goal posts), animate the ball along a curved
/// Magnus-driven path, and resolve a verdict.
///
/// Decoupled from the basketball + archery schemas on purpose: soccer's
/// signature physics is *sideways* — the ball curves around obstacles in
/// the horizontal plane — so the scene works in plan view rather than
/// elevation. The schema here carries just enough geometry to lay the
/// scene out and just enough spin to drive the Magnus curve.
struct SoccerScenario: Sendable, Equatable, Identifiable {
    let id: String

    /// User-visible name on the chapter list row.
    let title: String

    /// Phenomenon headline shown on the reveal card (Anton, big).
    let phenomenon: String

    /// 2–3 sentence reveal copy explaining WHY the ball did what it did.
    let explainer: String

    // MARK: - Free-kick geometry (meters)

    /// Distance from the spot to the goal line.
    let goalDistance: Double

    /// Distance from the spot to the defender wall — regulation is 9.15 m,
    /// but trick set-pieces stack the wall closer or further.
    let wallDistance: Double

    /// Width of the goal opening — regulation is 7.32 m.
    let goalWidth: Double

    /// Ball's launch velocity (m/s). 25–30 m/s is realistic for a struck
    /// free kick.
    let ballVelocity: Double

    // MARK: - The mechanic (Magnus law)

    /// Which physics mechanic this scenario teaches. Each chapter brings
    /// a new spin-driven behaviour: pure side spin curves around obstacles,
    /// topspin dips the ball under the bar, no spin sets up the erratic
    /// knuckleball, etc. Naming follows §11 voice rules — sport vocabulary,
    /// no "Magnus force".
    let mechanic: Mechanic

    /// Direction the ball curves on its way to the goal. Drives the scene's
    /// path animation and the verdict explanation.
    let curveDirection: CurveDirection

    /// Magnitude of the curve in meters at the goal line. Combined with
    /// `curveDirection` it picks the ball's final landing offset from the
    /// straight-line aim point.
    let curveAmount: Double

    /// Where the shooter is aiming, expressed as a fraction of `goalWidth`
    /// from the goal's centre (−1 = far left post, +1 = far right post,
    /// 0 = dead centre). Independent of the curve — the curve adds to the
    /// aim to find the actual landing spot.
    let aimOffset: Double

    // MARK: - Authored truth

    /// Whether this strike finds the net. Authored per-scenario rather
    /// than computed: the plan-view sim is too stylised to make a
    /// Magnus-derived truth feel accurate, so we trust the author and
    /// let the player learn the mechanic by watching the verdict.
    let willScore: Bool

    /// How the strike fails when `willScore` is false. Drives which
    /// verdict verb appears (SAVED / WIDE / OVER) and the explainer
    /// copy underneath it. Ignored when `willScore` is true.
    let failureMode: FailureMode

    // MARK: - Rebound teammate

    /// When true, an attacking teammate is placed on the pitch between
    /// the shooter and the goal. The ball can deflect off them to
    /// redirect into the net — the third Magnus dimension reserved for
    /// the later chapters (combine curve + aim + rebound to score).
    var hasTeammate: Bool = false
    /// Teammate's lateral position in normalized goal-mouth units
    /// (-1 = left post, +1 = right post). Ignored when `hasTeammate`
    /// is false.
    var teammateOffset: Double = 0
    /// Teammate's forward distance from the shooter in world meters.
    /// Ignored when `hasTeammate` is false.
    var teammateDistance: Double = 0

    // MARK: - Extra defender (rebound chapters)

    /// When true, an isolated defender is placed on the SAME forward
    /// line as the main wall, but offset laterally to one side. Its
    /// purpose in the rebound chapters is to close the direct shooting
    /// angle so the only path to score is through the rebound teammate.
    var hasExtraDefender: Bool = false
    /// Extra defender's lateral position in normalized half-width units.
    /// The forward distance is implicit: the scene anchors this figure
    /// to the wall's line.
    var extraDefenderOffset: Double = 0

    // MARK: - The lie

    /// Stance-screen prompt copy. Each mechanic reframes the YES/NO
    /// question slightly so the user knows what's being asked of them.
    var stancePrompt: String {
        switch mechanic {
        case .curve:     return "WILL IT CURVE IN?"
        case .dip:       return "WILL IT DIP UNDER?"
        case .knuckle:   return "WILL IT FOOL THE KEEPER?"
        case .banana:    return "WILL IT BEND HOME?"
        case .olympic:   return "WILL IT GO DIRECT?"
        }
    }

    /// Short label shown in the top info strip — the mechanic the user
    /// is being asked to read.
    var mechanicLabel: String { mechanic.displayName }

    // MARK: - Visual landing (descriptive, not authoritative)

    /// The ball's final horizontal offset from goal centre, in meters.
    /// Used for layout and copy hints; the verdict reads `willScore`,
    /// not this value.
    var landingOffset: Double {
        aimOffset * (goalWidth / 2.0) + curveDirection.signedHorizontal * curveAmount
    }

    /// The ball's final vertical offset at the goal line, in meters above
    /// the ground. Topspin dips, backspin lifts; lateral spin doesn't
    /// move the ball vertically.
    var landingHeight: Double {
        let baseHeight = 1.2  // chest-high aim is the typical free-kick line
        return baseHeight + curveDirection.signedVertical * curveAmount * 0.4
    }
}

// MARK: - Failure mode

extension SoccerScenario {
    /// Which way the strike misses when it doesn't go in. Picked by the
    /// scenario author so the verdict copy and the verb both line up
    /// with what the player just saw — a missed banana looks WIDE, a
    /// flat dip looks OVER, a centred curl looks SAVED.
    enum FailureMode: String, Sendable, Equatable {
        case savedByKeeper
        case wideOfPost
        case overTheBar
    }
}

// MARK: - Magnus mechanics

extension SoccerScenario {
    /// One per chapter. Each mechanic = one new piece of curve-physics
    /// intuition the player has to read.
    enum Mechanic: String, Sendable, Equatable, CaseIterable {
        case curve     // Ch1: sideways spin curves the ball around the wall
        case dip       // Ch2: topspin pulls the ball down hard
        case knuckle   // Ch3: no spin → unpredictable flutter
        case banana    // Ch4: heavy side spin from a wide angle
        case olympic   // Ch5: extreme spin straight off the corner flag

        var displayName: String {
            switch self {
            case .curve:    return "THE CURVE"
            case .dip:      return "THE DIP"
            case .knuckle:  return "THE KNUCKLE"
            case .banana:   return "THE BANANA"
            case .olympic:  return "THE OLYMPIC"
            }
        }
    }

    enum CurveDirection: String, Sendable, Equatable {
        case left, right, down, up, none

        /// +1 = right, −1 = left, 0 = vertical-only or none. Scales the
        /// horizontal curve magnitude before it's added to the aim.
        var signedHorizontal: Double {
            switch self {
            case .left:  return -1
            case .right: return  1
            case .down, .up, .none: return 0
            }
        }

        /// +1 = lift (backspin), −1 = dip (topspin), 0 = lateral-only.
        var signedVertical: Double {
            switch self {
            case .down: return -1
            case .up:   return  1
            case .left, .right, .none: return 0
            }
        }
    }
}
