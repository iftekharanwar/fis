import Foundation

/// Templated VoiceOver copy for the SpriteKit canvases, which expose nothing
/// to the accessibility tree on their own. Pure and stateless so the strings
/// are unit-testable without any scene or UI machinery.
///
/// Voice rules:
/// - The *label* carries the static geometry a sighted player sees in the
///   scene + HUD (distances, heights). That's information parity, not a leak.
/// - The frozen *reads* carry the same judgment evidence a sighted player
///   gets mid-flight — bucketed coarse enough that the call still takes
///   thought, and never naming the canonical θ/v numbers.
enum SceneNarration {

    // MARK: - Basketball

    /// Static court description: "Basketball court. Shooter 4.6 meters from
    /// the hoop. Rim 3 meters up."
    static func basketballLabel(params: Projectile2DParams) -> String {
        let dist = params.target.center[0] - params.releasePosition[0]
        let rimY = params.target.center[1]
        return "Basketball court. Shooter \(metres(dist)) from the hoop. "
            + "Rim \(metres(rimY)) up\(params.target.backboard != nil ? ", backboard behind it" : "")."
    }

    /// The apex read — what a sighted player judges while the ball hangs
    /// frozen. Computed from the *fired* shot (canonical or perturbed), so
    /// it carries genuine signal: a short shot peaks early and low, a long
    /// one carries deep.
    static func basketballFrozenRead(params: Projectile2DParams, shot: ProjectileAnswer) -> String {
        let g = max(params.gravity, 0.1)
        let theta = shot.thetaDegrees * .pi / 180
        let vx = shot.velocity * cos(theta)
        let vy = shot.velocity * sin(theta)
        let releaseX = params.releasePosition[0]
        let releaseY = params.releasePosition[1]
        let hoopX = params.target.center[0]
        let rimY = params.target.center[1]

        let tApex = vy / g
        let apexX = releaseX + vx * tApex
        let apexY = releaseY + (vy * vy) / (2 * g)
        let fraction = (apexX - releaseX) / max(hoopX - releaseX, 0.001)
        let heightOverRim = apexY - rimY

        let along: String
        switch fraction {
        case ..<0.35:      along = "less than a third of the way to the hoop"
        case 0.35..<0.5:   along = "approaching halfway to the hoop"
        case 0.5..<0.65:   along = "just past halfway to the hoop"
        case 0.65..<0.8:   along = "well past halfway to the hoop"
        default:           along = "nearly at the hoop"
        }

        let height: String
        switch heightOverRim {
        case ..<0:         height = "below rim height"
        case 0..<0.3:      height = "barely above rim height"
        case 0.3..<0.7:    height = "half a meter above the rim"
        case 0.7..<1.2:    height = "about a meter above the rim"
        case 1.2..<2.0:    height = "well above the rim"
        default:           height = "towering above the rim"
        }

        let arc: String
        switch shot.thetaDegrees {
        case ..<40:        arc = "The arc looks flat."
        case 40..<55:      arc = "The arc looks medium."
        default:           arc = "The arc looks high."
        }

        return "Ball frozen at the top of its arc — \(along), \(height). \(arc)"
    }

    // MARK: - Archery

    /// Static range description. The pin distance is on the HUD in plain
    /// sight — including it is parity, and it IS the scenario's tell.
    static func archeryLabel(_ s: ArcheryScenario) -> String {
        var text = "Archery range. Target \(metres(s.targetDistance)) out, "
            + "bullseye \(metres(s.bullseyeHeight)) up. "
            + "Pin sighted for \(metres(s.pinSightedFor)), arrow speed \(Int(s.arrowVelocity.rounded())) meters per second."
        if s.usesParadoxMechanic {
            text += " Bow draw \(Int(s.bowDraw)), arrow spine \(Int(s.arrowSpine))."
        }
        return text
    }

    /// The mid-flight read — arrow frozen at half the distance. Height vs
    /// the straight line to the bullseye is exactly what a sighted player
    /// eyeballs; for paradox scenarios the visible wobble is the evidence.
    static func archeryFrozenRead(_ s: ArcheryScenario) -> String {
        let theta = s.pinLaunchAngleRadians
        let vx = s.arrowVelocity * cos(theta)
        let vy = s.arrowVelocity * sin(theta)
        let xMid = s.targetDistance / 2
        let t = xMid / max(vx, 0.001)
        let yMid = s.releaseHeight + vy * t - 0.5 * s.gravity * t * t
        let sightLine = (s.releaseHeight + s.bullseyeHeight) / 2
        let delta = yMid - sightLine

        let line: String
        switch delta {
        case ..<(-0.5):    line = "well below the straight line to the bullseye"
        case -0.5..<(-0.15): line = "below the line to the bullseye"
        case -0.15..<0.15: line = "right on the line to the bullseye"
        case 0.15..<0.5:   line = "above the line to the bullseye"
        default:           line = "well above the straight line to the bullseye"
        }

        var text = "Arrow frozen mid-flight — \(line)."
        if s.usesParadoxMechanic {
            let mismatch = abs(s.spineMismatch)
            if mismatch >= 15 {
                text += " The shaft is flexing hard."
            } else if mismatch >= 5 {
                text += " The shaft is flexing visibly."
            } else {
                text += " The shaft looks steady."
            }
        }
        return text
    }

    // MARK: - Soccer

    /// Static set-piece description. Keeper offset is scene state (the view
    /// owns it), so it's passed in. Normalized offsets: ±1 = the posts.
    static func soccerLabel(_ s: SoccerScenario, keeperOffset: Double) -> String {
        var text = "Free kick, \(metres(s.goalDistance)) from goal. "
            + "Goal \(metres(s.goalWidth)) wide, wall \(metres(s.wallDistance)) out. "
        switch keeperOffset {
        case ..<(-0.15): text += "Keeper shading toward the left post."
        case 0.15...:    text += "Keeper shading toward the right post."
        default:         text += "Keeper central."
        }
        if s.hasTeammate {
            text += " A teammate waits in the box."
        }
        if s.hasExtraDefender {
            text += " An extra defender covers one side."
        }
        return text
    }

    /// The stance read — soccer's call happens before the kick, so this is
    /// where the evidence lives: aim, spin, and how hard the curve pulls.
    static func soccerStanceRead(_ s: SoccerScenario) -> String {
        let aim: String
        switch s.aimOffset {
        case ..<(-0.6):     aim = "aimed at the left post"
        case -0.6..<(-0.2): aim = "aimed left of center"
        case -0.2...0.2:    aim = "aimed at the center"
        case 0.2...0.6:     aim = "aimed right of center"
        default:            aim = "aimed at the right post"
        }

        let curve: String
        let dir = s.curveDirection
        if s.curveAmount < 0.3 || dir == SoccerScenario.CurveDirection.none {
            curve = "almost no curve on it"
        } else {
            let strength = s.curveAmount < 1.5 ? "a modest curve" : "a heavy curve"
            switch dir {
            case .left:  curve = "\(strength) bending left"
            case .right: curve = "\(strength) bending right"
            case .down:  curve = "\(strength) dipping down"
            case .up:    curve = "\(strength) rising"
            case .none:  curve = "almost no curve on it"
            }
        }

        return "\(s.mechanicLabel) strike, \(aim), \(curve)."
    }

    // MARK: - Formatting

    /// "4.6 meters" / "3 meters" — drop a trailing .0 so speech stays clean.
    private static func metres(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) meters"
        }
        return String(format: "%.1f meters", rounded)
    }
}
