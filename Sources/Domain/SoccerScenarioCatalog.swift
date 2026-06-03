import Foundation

/// Static catalog of soccer scenarios — one per chapter.
///
/// Progression curated for difficulty + mechanic discovery:
///   Ch1 — simple direct shot (curve, gentle parameters)
///   Ch2 — topspin / dip (Magnus rotation, vertical)
///   Ch3 — knuckler (no spin, erratic flutter)
///   Ch4 — first chapter with a teammate to rebound off
///   Ch5 — combined corner kick + teammate rebound
///
/// Each scenario carries its own visuals (wall position, keeper
/// stage are randomized at runtime in the play view) plus the Magnus
/// parameters the player will later tune via the SPIN / POWER / AIM
/// sliders during the compute beat.
enum SoccerScenarioCatalog {
    static let scenarios: [String: SoccerScenario] = [

        // Ch1 — simple direct shot, the canonical free-kick.
        "soc-curve-001": SoccerScenario(
            id: "soc-curve-001",
            title: "Place it past the wall.",
            phenomenon: "The curve.",
            explainer: "The ball spins around a vertical axis as it flies. One side cuts into the air, the other drags — and the pressure difference shoves the ball sideways. Aim past the wall, let the spin carry it home.",
            goalDistance: 25.0,
            wallDistance: 9.15,
            goalWidth: 7.32,
            ballVelocity: 27.0,
            mechanic: .curve,
            curveDirection: .right,
            curveAmount: 2.4,
            aimOffset: 0.0,
            willScore: true,
            failureMode: .savedByKeeper
        ),

        // Ch2 — dip / topspin: rotation pulls the ball down vertically.
        "soc-dip-001": SoccerScenario(
            id: "soc-dip-001",
            title: "Dip it under the bar.",
            phenomenon: "The dip.",
            explainer: "Topspin doesn't push sideways — it pushes DOWN. The top of the ball drags forward through the air; the air shoves the ball into the ground. From distance, that lets a struck shot rise over the keeper and drop in before the bar.",
            goalDistance: 22.0,
            wallDistance: 9.15,
            goalWidth: 7.32,
            ballVelocity: 30.0,
            mechanic: .dip,
            curveDirection: .down,
            curveAmount: 2.0,
            aimOffset: 0.0,
            willScore: true,
            failureMode: .overTheBar
        ),

        // Ch3 — knuckler: no spin, no Magnus force, but the airflow
        // chaotically flips and the ball wobbles late.
        "soc-knuckle-001": SoccerScenario(
            id: "soc-knuckle-001",
            title: "Strike it clean.",
            phenomenon: "The knuckle.",
            explainer: "Hit the ball dead-centre and it leaves with almost no spin. With no rotation there's no Magnus force — but the airflow flips chaotically across the surface, and the ball wobbles unpredictably. The keeper sees a straight shot, then watches it lurch sideways at the last instant.",
            goalDistance: 28.0,
            wallDistance: 9.15,
            goalWidth: 7.32,
            ballVelocity: 32.0,
            mechanic: .knuckle,
            curveDirection: .none,
            curveAmount: 0.6,
            aimOffset: 0.35,
            willScore: true,
            failureMode: .savedByKeeper
        ),

        // Ch4 — teammate as a rebound surface. An isolated defender
        // shadows the direct corner, so the only viable scoring path
        // is to strike the orange teammate and let the deflection do
        // the work.
        "soc-banana-001": SoccerScenario(
            id: "soc-banana-001",
            title: "Find the rebound.",
            phenomenon: "The deflection.",
            explainer: "From a wide angle the goal looks closed — but a teammate ghosting into the box can change the geometry. Strike the ball toward them, let the curve do the work, and a single touch off their boot redirects it into the open corner.",
            goalDistance: 24.0,
            wallDistance: 9.0,
            goalWidth: 7.32,
            ballVelocity: 26.0,
            mechanic: .banana,
            curveDirection: .left,
            curveAmount: 3.2,
            aimOffset: 0.5,
            willScore: true,
            failureMode: .wideOfPost,
            hasTeammate: true,
            teammateOffset: -0.55,
            teammateDistance: 17.0,
            hasExtraDefender: true,
            extraDefenderOffset: 0.55
        ),

        // Ch5 — corner + teammate + isolated defender. The defender
        // sits in the lane to the near post; the only path past the
        // keeper is the orange teammate's deflection on the far side.
        "soc-olympic-001": SoccerScenario(
            id: "soc-olympic-001",
            title: "Corner-flag combination.",
            phenomenon: "The set-piece rebound.",
            explainer: "From the corner flag, the goal is a closed angle. But place a teammate inside the box, curl the ball onto their head or chest, and one touch redirects it past the keeper — geometry the defenders can't account for from a flag kick alone.",
            goalDistance: 28.0,
            wallDistance: 12.0,
            goalWidth: 7.32,
            ballVelocity: 25.0,
            mechanic: .olympic,
            curveDirection: .left,
            curveAmount: 3.6,
            aimOffset: 0.7,
            willScore: true,
            failureMode: .wideOfPost,
            hasTeammate: true,
            teammateOffset: 0.45,
            teammateDistance: 20.0,
            hasExtraDefender: true,
            extraDefenderOffset: -0.55
        )
    ]

    static func scenario(for id: String) -> SoccerScenario? {
        scenarios[id]
    }

    /// Title shown on the chapter-list scenario row. Fallback humanizes
    /// the id for any not-yet-authored entry.
    static func title(for id: String) -> String {
        if let scenario = scenarios[id] { return scenario.title }
        return id.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
