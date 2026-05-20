import Foundation
import CoreGraphics

/// Player's projectile shot input: launch angle (degrees) and velocity (m/s).
struct ProjectileAnswer: Sendable, Equatable {
    let thetaDegrees: Double
    let velocity: Double
}

/// Immutable, render-ready slice. Contact fields are reserved for future per-frame
/// renderer reactions and stay zero/false/nil in MVP — contact detection runs in
/// `evaluate(history:_:)` instead.
struct ProjectileSnapshot: Sendable, Equatable {
    let ballPosition: CGPoint
    let ballVelocity: CGVector
    let elapsedSeconds: Double
    let rimContactCount: Int
    let backboardContactCount: Int
    let passedThroughHoopCenter: Bool
    /// Maintained per-step; used by `evaluate` to disambiguate SHORT misses.
    let maxHeight: Double
    let firstRimContactX: Double?
}

enum ProjectileOutcome: SimulationOutcome, Sendable, Equatable {
    case inFlight
    case success(flavor: String)
    case miss(category: String)

    var isResolved: Bool {
        switch self {
        case .inFlight: return false
        case .success, .miss: return true
        }
    }
}

/// Mutable simulation state. Not Sendable — Snapshot is the Sendable projection.
struct ProjectileState {
    var position: CGPoint
    var velocity: CGVector
    var elapsedSeconds: Double
    var rimContactCount: Int
    var backboardContactCount: Int
    var passedThroughHoopCenter: Bool
    var maxHeight: Double
    var firstRimContactX: Double?

    /// Carried in state so `step(state:dt:)` stays params-free.
    let gravity: Double
}

/// Semi-implicit Euler projectile integrator with basketball outcome decisions.
struct Projectile2DModule: SimulationModule, AnySimulationModule {
    typealias Params = Projectile2DParams
    typealias State = ProjectileState
    typealias Snapshot = ProjectileSnapshot
    typealias Answer = ProjectileAnswer
    typealias Outcome = ProjectileOutcome

    static let moduleId = "PROJECTILE_2D"
    static let moduleVersion = SemVer(1, 0, 0)

    static let staticModuleId = moduleId
    static let staticModuleVersion = moduleVersion

    func initState(params: Projectile2DParams, answer: ProjectileAnswer) -> ProjectileState {
        let releaseX = params.releasePosition[0]
        let releaseY = params.releasePosition[1]
        let theta = answer.thetaDegrees * .pi / 180.0
        let vx = answer.velocity * cos(theta)
        let vy = answer.velocity * sin(theta)
        return ProjectileState(
            position: CGPoint(x: releaseX, y: releaseY),
            velocity: CGVector(dx: vx, dy: vy),
            elapsedSeconds: 0,
            rimContactCount: 0,
            backboardContactCount: 0,
            passedThroughHoopCenter: false,
            maxHeight: releaseY,
            firstRimContactX: nil,
            gravity: params.gravity
        )
    }

    func step(state: ProjectileState, dt: Double) -> ProjectileState {
        var s = state
        // Semi-implicit Euler: velocity first, then position with the new velocity.
        s.velocity.dy -= s.gravity * dt
        s.position.x += s.velocity.dx * dt
        s.position.y += s.velocity.dy * dt
        s.elapsedSeconds += dt
        s.maxHeight = max(s.maxHeight, s.position.y)
        return s
    }

    func snapshot(state: ProjectileState) -> ProjectileSnapshot {
        ProjectileSnapshot(
            ballPosition: state.position,
            ballVelocity: state.velocity,
            elapsedSeconds: state.elapsedSeconds,
            rimContactCount: state.rimContactCount,
            backboardContactCount: state.backboardContactCount,
            passedThroughHoopCenter: state.passedThroughHoopCenter,
            maxHeight: state.maxHeight,
            firstRimContactX: state.firstRimContactX
        )
    }

    func evaluate(history: [Projectile2DModule.Snapshot], params: Projectile2DParams) -> ProjectileOutcome {
        guard let latest = history.last else { return .inFlight }

        let hoop = params.target
        let hoopX = hoop.center[0]
        let hoopY = hoop.center[1]
        let ballR = params.ball.radius

        let passedThrough = detectHoopPassThrough(history: history, hoop: hoop)

        let rimHit = isWithinRimShell(point: latest.ballPosition, hoop: hoop, ballRadius: ballR)
        let backboardHit = (hoop.backboard.map { isWithinBackboardRect(point: latest.ballPosition, backboard: $0, ballRadius: ballR) }) ?? false

        let world = params.world
        let outOfBounds = latest.ballPosition.x < world.xMin
                       || latest.ballPosition.x > world.xMax
                       || latest.ballPosition.y < world.floorY
                       || latest.ballPosition.y > world.yMax

        let totalRimContacts = countRimContacts(history: history, hoop: hoop, ballRadius: ballR)
        let totalBackboardContacts = countBackboardContacts(history: history, hoop: hoop, ballRadius: ballR)

        if passedThrough {
            if totalRimContacts == 0 && totalBackboardContacts == 0 {
                return .success(flavor: "SWISH")
            } else if totalRimContacts == 0 && totalBackboardContacts >= 1 {
                return .success(flavor: "GLASS")
            } else {
                return .success(flavor: "RIM_DROP")
            }
        }

        if outOfBounds {
            return .miss(category: missCategory(history: history, hoop: hoop, ballRadius: ballR))
        }

        return .inFlight
    }

    func reset() {}

    /// Vertical guard prevents a trajectory that arcs cleanly over the rim from being
    /// counted as contact just because it passed within `ballRadius + rimThickness`
    /// of a rim point at some other height.
    private func isWithinRimShell(
        point: CGPoint,
        hoop: Projectile2DParams.TargetParams,
        ballRadius: Double
    ) -> Bool {
        let hoopX = hoop.center[0]
        let hoopY = hoop.center[1]
        let r = hoop.innerRadius
        guard abs(point.y - hoopY) <= hoop.rimThickness else { return false }
        let absDxFromCenter = abs(point.x - hoopX)
        return abs(absDxFromCenter - r) <= hoop.rimThickness
    }

    private func isWithinBackboardRect(
        point: CGPoint,
        backboard: Projectile2DParams.BackboardParams,
        ballRadius: Double
    ) -> Bool {
        let bx = backboard.position[0]
        let by = backboard.position[1]
        let halfW = backboard.width / 2
        let halfH = backboard.height / 2
        let dx = point.x - bx
        let dy = point.y - by
        return abs(dx) <= halfW + ballRadius && abs(dy) <= halfH
    }

    private func detectHoopPassThrough(
        history: [Projectile2DModule.Snapshot],
        hoop: Projectile2DParams.TargetParams
    ) -> Bool {
        guard history.count >= 2 else { return false }
        let hoopX = hoop.center[0]
        let hoopY = hoop.center[1]
        for i in 1..<history.count {
            let prev = history[i - 1].ballPosition
            let cur = history[i].ballPosition
            if prev.y > hoopY && cur.y <= hoopY {
                // Interpolate x at the crossing.
                let t = (prev.y - hoopY) / max(0.0001, prev.y - cur.y)
                let crossingX = prev.x + (cur.x - prev.x) * t
                if abs(crossingX - hoopX) < hoop.innerRadius {
                    return true
                }
            }
        }
        return false
    }

    /// Counts distinct contact events; consecutive contact frames collapse into one.
    private func countRimContacts(
        history: [Projectile2DModule.Snapshot],
        hoop: Projectile2DParams.TargetParams,
        ballRadius: Double
    ) -> Int {
        var count = 0
        var inContact = false
        for snap in history {
            let nowInContact = isWithinRimShell(point: snap.ballPosition, hoop: hoop, ballRadius: ballRadius)
            if nowInContact && !inContact { count += 1 }
            inContact = nowInContact
        }
        return count
    }

    private func countBackboardContacts(
        history: [Projectile2DModule.Snapshot],
        hoop: Projectile2DParams.TargetParams,
        ballRadius: Double
    ) -> Int {
        guard let backboard = hoop.backboard else { return 0 }
        var count = 0
        var inContact = false
        for snap in history {
            let nowInContact = isWithinBackboardRect(point: snap.ballPosition, backboard: backboard, ballRadius: ballRadius)
            if nowInContact && !inContact { count += 1 }
            inContact = nowInContact
        }
        return count
    }

    private func missCategory(
        history: [Projectile2DModule.Snapshot],
        hoop: Projectile2DParams.TargetParams,
        ballRadius: Double
    ) -> String {
        guard let last = history.last else { return "AIRBALL" }
        let hoopX = hoop.center[0]
        let hoopY = hoop.center[1]
        let rimContacts = countRimContacts(history: history, hoop: hoop, ballRadius: ballRadius)
        let backboardContacts = countBackboardContacts(history: history, hoop: hoop, ballRadius: ballRadius)

        var firstRimX: Double?
        for snap in history {
            if isWithinRimShell(point: snap.ballPosition, hoop: hoop, ballRadius: ballRadius) {
                firstRimX = snap.ballPosition.x
                break
            }
        }

        if rimContacts >= 1, let frx = firstRimX {
            if frx < hoopX - 0.05 { return "FRONT_RIM" }
            if frx > hoopX + 0.05 { return "BACK_RIM" }
        }

        if last.maxHeight < hoopY { return "SHORT" }
        if last.ballPosition.x > hoopX + 0.5 { return "OVERSHOOT" }
        if rimContacts == 0 && backboardContacts == 0 { return "AIRBALL" }

        return "AIRBALL"
    }
}
