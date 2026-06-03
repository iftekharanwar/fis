import SpriteKit
import UIKit

/// Outcome the SpriteKit scene emits when the arrow crosses the target plane.
enum ArcheryOutcome: Equatable, Sendable {
    case hitBullseye
    case missHigh(byMeters: Double)
    case missLow(byMeters: Double)

    var didHit: Bool {
        if case .hitBullseye = self { return true } else { return false }
    }

    var offsetMeters: Double {
        switch self {
        case .hitBullseye:                 return 0
        case .missHigh(let by):            return by
        case .missLow(let by):             return -by
        }
    }
}

/// SpriteKit scene for archery scenarios.
///
/// World transform is intentionally non-uniform (separate x/y scales) so the
/// ~0.6 m vertical drop over 40 m horizontal flight is actually visible —
/// uniform scale would compress the drop into a handful of pixels. The
/// figure and the bow are drawn in scene-pixel coordinates relative to the
/// archer's anchor point so they don't get y-stretched.
///
/// Visual identity is sourced from the archery SVG pack: rounded white
/// stickman, recurve bow with a straight string and a small orange grip,
/// cream-shafted arrow with a red-orange triangular point.
final class ArcherySceneNode: SKScene {

    let scenario: ArcheryScenario

    /// Sim seconds per real second at normal playback. Higher = closer to
    /// real time. The arrow's TRUE flight time scales with velocity (40m / v),
    /// so when the user cranks power the on-screen flight is punchy-quick; at
    /// low power the arrow visibly arcs and lingers. Was 0.25 (uniform
    /// slow-mo) — that made power changes feel meaningless.
    ///
    /// The *effective* time scale now varies across the flight via
    /// `currentTimeScale()` — full speed off the string, a cinematic slow-mo
    /// through the middle third, then back to full speed into the target.
    private let timeScaleNormal: Double = 0.65

    /// Time scale during the mid-flight slow-mo window. ~3.6× slower than
    /// normal — enough to read as "bullet time" without dragging.
    private let timeScaleSlow: Double = 0.18

    /// Mid-flight slow-mo window, as a fraction of horizontal flight (x /
    /// targetDistance). Full speed before `slowStart`, eased to slow across
    /// the next `rampWidth`, held slow until `slowEnd`, eased back to full.
    private let slowStart: Double = 0.32
    private let slowEnd: Double = 0.68
    private let rampWidth: Double = 0.10

    // MARK: - Mid-flight call freeze

    /// Fired once when the arrow reaches `midflightFreezeFraction` of its
    /// horizontal flight, *if* the shot was launched with `pauseAtMidflight`.
    /// Drives the call beat: the play view freezes here and shows YES / NO,
    /// then calls `resumeFlight()`.
    var onReachedMidflight: (() -> Void)?

    /// Whether the current shot should freeze mid-flight for the call.
    private var pauseAtMidflight: Bool = false
    /// Guard so the freeze fires exactly once per shot.
    private var midflightTriggered: Bool = false
    /// Set once the user has resumed past the freeze, so it never re-fires.
    private var midflightDone: Bool = false
    /// Fraction of horizontal flight at which the call freeze happens.
    private let midflightFreezeFraction: Double = 0.5

    private var transform: ArcheryTransform!
    private(set) var uiReserve: SceneInsets = .zero

    // Static nodes
    private var archerNode: SKNode?
    private var bowNode: SKNode?
    private var restingArrowNode: SKNode?
    private var targetNode: SKNode?
    private var pinNode: SKShapeNode?

    // Dynamic
    private var flightArrowNode: SKNode?
    private var trailNode: SKShapeNode?
    private var trailPoints: [CGPoint] = []   // world meters
    private var ghostNode: SKShapeNode?

    /// Remembered ghost args. SpriteKit's didChangeSize fires AFTER
    /// SwiftUI's onAppear, so the play view's first setGhost gets wiped
    /// by the post-onAppear scene rebuild. Persisting the args lets the
    /// scene re-draw the ghost itself whenever the graph rebuilds.
    private var pendingGhostHoldoverCm: Double?
    private var pendingGhostVelocity: Double = 80.0

    // Sim
    private var simPosition: CGPoint = .zero
    private var simVelocity: CGVector = .zero
    private var isSimulating: Bool = false
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: Double = 0
    private let fixedDt: Double = 1.0 / 240.0

    /// Sim time since `fireArrow` — used to drive the wobble decay and
    /// frequency for the archer's-paradox visual. Resets on each shot.
    private var flightElapsedTime: Double = 0

    /// Current display angle for the bow + resting arrow, in radians of
    /// SCREEN-space tilt (not world). Recomputed whenever holdover or
    /// velocity changes; the stance default is the pin's calibration angle.
    private var currentBowScreenAngle: CGFloat = 0

    var audio: AudioService?

    /// Multiplier for hardcoded cosmetic pixel constants (target rings, pin,
    /// trail, ground line) so they stay visible on a large iPad canvas. Derived
    /// from the smaller scene dimension vs the iPhone baseline (~393pt); never
    /// below 1.0, capped so iPad isn't cartoonish. Figure/bow/arrow strokes are
    /// already derived from figureHeight/svgScale and intentionally excluded.
    var cosmeticScale: CGFloat {
        min(max(min(size.width, size.height) / 393, 1.0), 2.2)
    }

    /// (outcome, wobbleAtImpactRadians) — the wobble envelope value
    /// at the moment the arrow crosses the target plane. Ch1 scenarios
    /// always have wobble=0; Ch2 (paradox) scenarios use this to decide
    /// "clean flight" vs "wobbled" for the verdict.
    var onOutcomeResolved: ((ArcheryOutcome, Double) -> Void)?

    init(scenario: ArcheryScenario, size: CGSize) {
        self.scenario = scenario
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = .black
        self.anchorPoint = CGPoint(x: 0, y: 0)
        rebuildTransform(for: size)
        buildSceneGraph()
        resetSimulationState()
        applyBowAngle(worldLaunchAngle: scenario.pinLaunchAngleRadians,
                      velocity: scenario.arrowVelocity)
        updateFlightArrowVisual()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ArcherySceneNode does not support init(coder:)")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != .zero else { return }
        rebuildTransform(for: size)
        rebuildSceneGraph()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if view.bounds.size != .zero, view.bounds.size != size {
            size = view.bounds.size
        }
    }

    // MARK: - Public control

    func applyUIReserve(top: CGFloat, bottom: CGFloat, safeTop: CGFloat, safeBottom: CGFloat, right: CGFloat = 0) {
        let next = SceneInsets(top: top, bottom: bottom, safeTop: safeTop, safeBottom: safeBottom, right: right)
        guard next != uiReserve else { return }
        uiReserve = next
        rebuildTransform(for: size)
        rebuildSceneGraph()
    }

    /// Fire the arrow with the pin's calibration angle (call-mode default).
    /// `pauseAtMidflight` freezes the arrow mid-flight for the call beat —
    /// the user predicts YES/NO while the arrow hangs, then `resumeFlight()`
    /// carries it home. Compute/bonus shots pass false (no freeze).
    func startSimulation(pauseAtMidflight: Bool = false) {
        fireArrow(launchAngle: scenario.pinLaunchAngleRadians,
                  velocity: scenario.arrowVelocity,
                  pauseAtMidflight: pauseAtMidflight)
    }

    /// Fire the arrow with the user's chosen holdover and velocity (compute mode).
    /// The extra elevation is added to the pin's calibration angle by
    /// δθ = H / d_target (small-angle approximation).
    func startSimulation(holdoverCm: Double, velocity: Double) {
        let extraAngle = (holdoverCm / 100.0) / scenario.targetDistance
        fireArrow(launchAngle: scenario.pinLaunchAngleRadians + extraAngle,
                  velocity: velocity)
    }

    /// Paradox-mode fire: user picks SPINE, everything else uses scenario
    /// defaults (calibrated angle, fixed velocity, scenario's bowDraw).
    /// `userSpine - scenario.bowDraw` drives the wobble for this shot.
    func startSimulation(spineOverride: Double) {
        fireArrow(
            launchAngle: scenario.pinLaunchAngleRadians,
            velocity: scenario.arrowVelocity,
            spineOverride: spineOverride
        )
    }

    /// Resume a shot that was frozen at the mid-flight call beat. The arrow
    /// continues from where it hung; no further freeze this shot.
    func resumeFlight() {
        guard !isSimulating, !midflightDone else { return }
        midflightDone = true
        pauseAtMidflight = false
        isSimulating = true
        lastUpdateTime = 0   // re-seed dt so we don't jump on the first frame
        accumulator = 0
    }

    private func fireArrow(launchAngle: Double, velocity: Double, spineOverride: Double? = nil, pauseAtMidflight: Bool = false) {
        clearGhost()
        applyBowAngle(worldLaunchAngle: launchAngle, velocity: velocity)
        simPosition = CGPoint(x: 0, y: scenario.releaseHeight)
        simVelocity = CGVector(
            dx: velocity * cos(launchAngle),
            dy: velocity * sin(launchAngle)
        )
        trailPoints = [simPosition]
        isSimulating = true
        self.pauseAtMidflight = pauseAtMidflight
        midflightTriggered = false
        midflightDone = false
        accumulator = 0
        lastUpdateTime = 0
        flightElapsedTime = 0
        // Lock in the spine mismatch driving wobble for this shot.
        // Compute mode passes the user's chosen spine; otherwise we use
        // the scenario's authored value.
        if let userSpine = spineOverride {
            activeSpineMismatch = userSpine - scenario.bowDraw
        } else {
            activeSpineMismatch = scenario.spineMismatch
        }
        // Release pair — bowRelease layers over arrowWhoosh. bowRelease
        // currently has no asset on disk and no-ops gracefully; arrowWhoosh
        // carries the moment until the twang sample lands.
        audio?.play(.bowRelease)
        audio?.play(.arrowWhoosh)
        restingArrowNode?.isHidden = true
        flightArrowNode?.isHidden = false
        updateFlightArrowVisual()
        updateTrailVisual()
    }

    func resetForNewShot() {
        isSimulating = false
        resetSimulationState()
        clearGhost()
        restingArrowNode?.isHidden = false
        flightArrowNode?.isHidden = true
        applyBowAngle(worldLaunchAngle: scenario.pinLaunchAngleRadians,
                      velocity: scenario.arrowVelocity)
        updateFlightArrowVisual()
        updateTrailVisual()
    }

    /// Live ghost trajectory preview. Pass nil to hide. Also rotates the
    /// bow to match the new launch angle so the user SEES the bow tracking
    /// their chosen holdover/velocity before they fire.
    func setGhost(holdoverCm: Double?, velocity: Double) {
        pendingGhostHoldoverCm = holdoverCm
        pendingGhostVelocity = velocity
        guard let cm = holdoverCm else {
            clearGhost()
            applyBowAngle(worldLaunchAngle: scenario.pinLaunchAngleRadians,
                          velocity: scenario.arrowVelocity)
            return
        }
        let extraAngle = (cm / 100.0) / scenario.targetDistance
        let theta = scenario.pinLaunchAngleRadians + extraAngle
        applyBowAngle(worldLaunchAngle: theta, velocity: velocity)
        drawGhostTrajectory(launchAngle: theta, velocity: velocity)
    }

    // MARK: - Bow rotation

    private func applyBowAngle(worldLaunchAngle: Double, velocity: Double) {
        let screenAngle = screenAngleForWorldLaunch(worldLaunchAngle, velocity: velocity)
        currentBowScreenAngle = CGFloat(screenAngle)
        bowNode?.zRotation = currentBowScreenAngle
    }

    /// Convert a world-space launch angle into the visible on-screen angle.
    /// Necessary because the scene's y axis is stretched relative to x —
    /// using world angle here would point the bow much flatter than the
    /// arc the user actually sees on screen.
    private func screenAngleForWorldLaunch(_ worldAngle: Double, velocity: Double) -> Double {
        let vxWorld = velocity * cos(worldAngle)
        let vyWorld = velocity * sin(worldAngle)
        let vxScreen = vxWorld * Double(transform.xScale)
        let vyScreen = vyWorld * Double(transform.yScale)
        return atan2(vyScreen, vxScreen)
    }

    // MARK: - Ghost trajectory

    private func drawGhostTrajectory(launchAngle: Double, velocity: Double) {
        let vx = velocity * cos(launchAngle)
        let vy = velocity * sin(launchAngle)
        guard vx > 0 else { clearGhost(); return }
        let tTarget = scenario.targetDistance / vx
        // Only sample the FIRST third of the flight. The ghost shows the
        // launch direction so the user can read "high or low?" but it
        // doesn't paint the landing point — they still have to predict
        // where it'll fall from physics intuition.
        let totalSamples = 32
        let visibleSamples = totalSamples / 3   // ~10 samples
        var worldPts: [CGPoint] = []
        for i in 0...visibleSamples {
            let t = tTarget * Double(i) / Double(totalSamples)
            let x = vx * t
            let y = scenario.releaseHeight + vy * t - 0.5 * scenario.gravity * t * t
            worldPts.append(CGPoint(x: x, y: y))
        }
        renderGhost(worldPts: worldPts)
    }

    private func renderGhost(worldPts: [CGPoint]) {
        if ghostNode == nil {
            let node = SKShapeNode()
            node.strokeColor = UIColor.white.withAlphaComponent(0.65)
            node.lineWidth = 1.6 * cosmeticScale
            node.fillColor = .clear
            // SKShapeNode supports a glLineLength / dashPattern style via
            // SKAction; cheapest reliable approach is to build the dashed
            // path manually from line segments (avoids platform quirks
            // with CGPath.copy(dashingWithPhase:lengths:) on some iOS
            // versions where the dashed copy returns an empty path).
            addChild(node)
            ghostNode = node
        }
        guard let ghostNode, worldPts.count > 1 else { return }
        let scenePts = worldPts.map { transform.scenePoint(world: $0) }
        // Manual dash: take every other segment between sample points.
        // With 32 samples that's 16 dashes — reads as a dotted preview.
        let path = CGMutablePath()
        for i in stride(from: 0, to: scenePts.count - 1, by: 2) {
            path.move(to: scenePts[i])
            path.addLine(to: scenePts[i + 1])
        }
        ghostNode.path = path
    }

    private func clearGhost() {
        ghostNode?.path = nil
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard isSimulating else { return }
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let realDt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        accumulator += min(realDt * currentTimeScale(), 0.05)

        while accumulator >= fixedDt && isSimulating {
            stepSimulation()
            accumulator -= fixedDt
            if !isSimulating { break }   // a mid-flight freeze ended the sim
        }

        updateFlightArrowVisual()
        updateTrailVisual()
    }

    /// Playback speed at the arrow's current position: full speed off the
    /// string, eased into a slow-mo window through the middle of the flight,
    /// then eased back to full speed into the target. Produces the
    /// "normal → slo-mo → normal" cinematic without changing the physics
    /// (the fixed-dt integrator is untouched; only how fast we feed it real
    /// time varies).
    private func currentTimeScale() -> Double {
        let dx = scenario.targetDistance
        guard dx > 0 else { return timeScaleNormal }
        let progress = max(0, min(1, simPosition.x / dx))

        // smoothstep ramp helper.
        func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
            guard b > a else { return x < a ? 0 : 1 }
            let t = max(0, min(1, (x - a) / (b - a)))
            return t * t * (3 - 2 * t)
        }

        // 0 before slow window, 1 inside it, eased on both edges.
        let rampIn  = smooth(slowStart, slowStart + rampWidth, progress)
        let rampOut = smooth(slowEnd - rampWidth, slowEnd, progress)
        let slowAmount = rampIn * (1 - rampOut)   // peaks at 1 in the middle

        return timeScaleNormal + (timeScaleSlow - timeScaleNormal) * slowAmount
    }

    private func stepSimulation() {
        simVelocity.dy -= scenario.gravity * fixedDt
        simPosition.x += simVelocity.dx * fixedDt
        simPosition.y += simVelocity.dy * fixedDt
        trailPoints.append(simPosition)
        flightElapsedTime += fixedDt

        // Mid-flight call freeze — pause once the arrow passes the freeze
        // point so the user can predict YES/NO while it hangs. Fires only
        // when the shot was launched with pauseAtMidflight (the call beat),
        // and only once per shot.
        if pauseAtMidflight, !midflightTriggered,
           simPosition.x >= scenario.targetDistance * midflightFreezeFraction {
            midflightTriggered = true
            isSimulating = false
            onReachedMidflight?()
            return
        }

        guard simPosition.x >= scenario.targetDistance else { return }

        let lastIdx = trailPoints.count - 2
        guard lastIdx >= 0 else { return }
        let last = trailPoints[lastIdx]
        let curr = trailPoints[trailPoints.count - 1]
        let dx = curr.x - last.x
        let alpha = dx > 0 ? (scenario.targetDistance - last.x) / dx : 0
        let impactY = last.y + (curr.y - last.y) * alpha
        simPosition = CGPoint(x: scenario.targetDistance, y: impactY)
        trailPoints[trailPoints.count - 1] = simPosition
        isSimulating = false

        let offset = impactY - scenario.bullseyeHeight
        let outcome: ArcheryOutcome
        if abs(offset) <= scenario.bullseyeRadius {
            outcome = .hitBullseye
            audio?.play(.bullseyeHit)
        } else if offset > 0 {
            outcome = .missHigh(byMeters: offset)
            audio?.play(.targetThud)
        } else {
            outcome = .missLow(byMeters: -offset)
            audio?.play(.targetThud)
        }
        // Envelope (not the instantaneous sine) at the moment of impact —
        // this is what the play view uses to judge clean vs wobbled.
        let wobbleAtImpact = wobbleEnvelope(at: flightElapsedTime,
                                            mismatch: activeSpineMismatch)
        onOutcomeResolved?(outcome, wobbleAtImpact)
    }

    private func resetSimulationState() {
        simPosition = CGPoint(x: 0, y: scenario.releaseHeight)
        simVelocity = .zero
        trailPoints = []
        accumulator = 0
        lastUpdateTime = 0
        flightElapsedTime = 0
        pauseAtMidflight = false
        midflightTriggered = false
        midflightDone = false
    }

    // MARK: - Scene graph

    private func rebuildTransform(for size: CGSize) {
        // 8 m of world space behind the archer so the figure's body
        // (drawn to the LEFT of the hand-at-world-origin) isn't pushed
        // off the left edge. 3 m past the target so the trail has room
        // to settle visually.
        //
        // worldYMax = 5 (was 3) cuts the y-stretch from ~25× to ~15×.
        // The visible arc is still readable (~30 px above release for a
        // 0.32 m world rise) but the arrow's screen-angle change shrinks
        // from ~74° to ~50° total — closer to the real ±1.76°.
        transform = ArcheryTransform(
            sceneSize: size,
            uiReserve: uiReserve,
            worldXMin: -8,
            worldXMax: scenario.targetDistance + 3,
            worldYMin: 0,
            worldYMax: 5.0
        )
    }

    private func rebuildSceneGraph() {
        removeAllChildren()
        archerNode = nil
        bowNode = nil
        restingArrowNode = nil
        targetNode = nil
        pinNode = nil
        flightArrowNode = nil
        trailNode = nil
        ghostNode = nil
        buildSceneGraph()
        applyBowAngle(worldLaunchAngle: scenario.pinLaunchAngleRadians,
                      velocity: scenario.arrowVelocity)
        updateFlightArrowVisual()
        updateTrailVisual()
        // Restore in-flight visibility — fresh nodes default to visible
        // (resting) and hidden (flight). If we're mid-sim, swap them.
        if isSimulating {
            restingArrowNode?.isHidden = true
            flightArrowNode?.isHidden = false
        }
        // Re-apply any pending ghost — covers the case where SwiftUI's
        // onAppear seeded the ghost before SpriteKit's didChangeSize
        // triggered a rebuild.
        if let cm = pendingGhostHoldoverCm {
            let extraAngle = (cm / 100.0) / scenario.targetDistance
            let theta = scenario.pinLaunchAngleRadians + extraAngle
            applyBowAngle(worldLaunchAngle: theta, velocity: pendingGhostVelocity)
            drawGhostTrajectory(launchAngle: theta, velocity: pendingGhostVelocity)
        }
    }

    private func buildSceneGraph() {
        buildArcher()        // figure first (computes feet position)
        buildGroundLine()    // ground sits at the figure's feet, not at world y=0
        buildBow()           // bow + resting arrow (rotatable)
        buildTarget()
        buildPin()
        buildTrail()
        buildFlightArrow()
    }

    /// Fixed-pixel figure height. Smaller cap so a 1.6 m archer reads
    /// like a 1.6 m archer next to a 40 m target — not a 20 m giant.
    /// All other visuals (bow, arrow, ground line) derive from this so
    /// they shrink together and keep proportion.
    private var figureHeight: CGFloat {
        min(130, max(95, size.height * 0.15))
    }

    /// Single source of truth for arrow size. Both the bow's resting
    /// arrow and the in-flight arrow scale from this — keeps them the
    /// same size from nock to landing.
    private var arrowScale: CGFloat {
        (figureHeight * 0.65) / 100
    }

    /// Scene point where the bow grip sits — i.e. world (0, releaseHeight).
    /// Both the figure (via hand offset) and the bow are anchored from here
    /// so the trajectory's start point glues to the visible grip.
    private var bowGripScene: CGPoint {
        transform.scenePoint(world: CGPoint(x: 0, y: scenario.releaseHeight))
    }

    /// Scene point at the figure's feet, derived from the bow grip minus
    /// the figure's local hand offset. Lets the figure size stay constant
    /// regardless of how the world is mapped to scene space.
    private var feetScene: CGPoint {
        CGPoint(
            x: bowGripScene.x - figureHeight * 0.22,
            y: bowGripScene.y - figureHeight * 0.74
        )
    }

    private func buildGroundLine() {
        // Ground at the figure's feet — the trajectory + target are still
        // anchored to world coords, but the visual ground tracks the
        // figure so the archer doesn't appear to float in space.
        let path = CGMutablePath()
        let leftPt = CGPoint(x: transform.scenePoint(world: CGPoint(x: transform.worldXMin, y: 0)).x,
                             y: feetScene.y)
        let rightPt = CGPoint(x: transform.scenePoint(world: CGPoint(x: transform.worldXMax, y: 0)).x,
                              y: feetScene.y)
        path.move(to: leftPt)
        path.addLine(to: rightPt)
        let line = SKShapeNode(path: path)
        line.strokeColor = Self.borderGrey
        line.lineWidth = 1 * cosmeticScale
        addChild(line)
    }

    // MARK: - Archer (stickman from Stickman.svg geometry)

    private func buildArcher() {
        let group = SKNode()
        group.position = feetScene

        let h = figureHeight
        let lineWidth: CGFloat = 4.5
        let strokeColor: UIColor = .white

        // Proportions roughly matching Stickman.svg:
        //   head 14%, body 14–50%, legs 50–100%, arm attaches at ~74%.
        let headRadius = h * 0.075
        let headCenter = CGPoint(x: 0, y: h - headRadius - 3)
        let neck = CGPoint(x: 0, y: headCenter.y - headRadius - 2)
        let hip = CGPoint(x: 0, y: h * 0.50)
        let shoulder = CGPoint(x: 0, y: h * 0.74)
        let footSpread = h * 0.08

        // Body
        group.addChild(strokeLine(from: neck, to: hip, color: strokeColor, width: lineWidth))

        // Legs (V)
        group.addChild(strokeLine(from: hip, to: CGPoint(x: -footSpread, y: 0),
                                  color: strokeColor, width: lineWidth))
        group.addChild(strokeLine(from: hip, to: CGPoint(x:  footSpread, y: 0),
                                  color: strokeColor, width: lineWidth))

        // Front arm — reaches from shoulder forward to the bow grip. The
        // hand's local point is (h*0.22, h*0.74) which equals bowGripScene
        // after the group's position offset, so the bow visually meets
        // the hand cleanly.
        let hand = CGPoint(x: h * 0.22, y: shoulder.y)
        group.addChild(strokeLine(from: shoulder, to: hand,
                                  color: strokeColor, width: lineWidth))

        // Head
        let head = SKShapeNode(circleOfRadius: headRadius)
        head.position = headCenter
        head.fillColor = .white
        head.strokeColor = .white
        head.lineWidth = 0
        group.addChild(head)

        addChild(group)
        archerNode = group
    }

    private func strokeLine(from a: CGPoint, to b: CGPoint, color: UIColor, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        return node
    }

    // MARK: - Bow (recurve from Bow.svg geometry) + resting arrow

    private func buildBow() {
        // Bow centered at the world release point — same scene point the
        // figure's hand reaches to and the flight arrow leaves from. The
        // bow's GRIP is at this origin (matching how a real archer holds
        // the bow), and the rotation pivot is the grip.
        let group = SKNode()
        group.position = bowGripScene

        // SVG bow total height = 289. Scale so the bow's pixel height
        // matches a sensible fraction of the figure — the bow shouldn't
        // dwarf the archer.
        let bowTotalHeight = figureHeight * 0.65
        let svgScale = bowTotalHeight / Self.svgBowHeight

        // Build the three bow components from the SVG path data, scaled
        // and translated so the grip center lands at local (0, 0).
        let limbPath = Self.svgBowLimbPath(scale: svgScale)
        let stringPath = Self.svgBowStringPath(scale: svgScale)
        let gripPath = Self.svgBowGripPath(scale: svgScale)

        // Limb — white outer curve, thick stroke (proportional to SVG's 16pt).
        let limb = SKShapeNode(path: limbPath)
        limb.strokeColor = .white
        limb.lineWidth = max(16 * svgScale, 2)
        limb.lineCap = .round
        limb.fillColor = .clear
        group.addChild(limb)

        // Bowstring — orange-brown (#DB540C), thin (proportional to SVG's 3pt).
        let string = SKShapeNode(path: stringPath)
        string.strokeColor = Self.bowStringOrange
        string.lineWidth = max(3 * svgScale, 1)
        string.lineCap = .round
        group.addChild(string)

        // Grip — leaf-shaped orange detail at the center, matches SVG path.
        let grip = SKShapeNode(path: gripPath)
        grip.fillColor = Self.bowGripOrange
        grip.strokeColor = Self.bowGripOrange
        grip.lineWidth = 0
        group.addChild(grip)

        // Resting arrow — nocked on the string. String is now at local
        // x = -SVG offset (behind the grip); the arrow's back-of-shaft
        // must sit there, tip extends forward past the limb's bulge.
        // Uses `arrowScale` so it stays exactly the same size as the
        // flight arrow — no jarring size jump at release.
        let stringX = Self.svgBowStringX(scale: svgScale)
        let restingArrow = makeArrowNode(scale: arrowScale)
        let restingShaftLength = Self.arrowBaseShaft * arrowScale
        // Center the arrow such that its back sits at stringX.
        restingArrow.position = CGPoint(x: stringX + restingShaftLength * 0.5, y: 0)
        group.addChild(restingArrow)
        restingArrowNode = restingArrow

        addChild(group)
        bowNode = group
    }

    // MARK: - SVG bow path helpers
    //
    // Reference coordinates pulled from archery/Bow.svg. All paths are
    // re-anchored to the grip center (171.4, 197 in SVG) so the bow's
    // rotation pivot matches the archer's hand position.

    private static let svgBowHeight: CGFloat = 289           // 341.465 − 52.5315
    private static let svgGripCenter = CGPoint(x: 171.4, y: 197)

    /// Convert an SVG point into bow-local coords (grip at origin, y-up).
    private static func svgToLocal(_ p: CGPoint, scale: CGFloat) -> CGPoint {
        let dx = (p.x - svgGripCenter.x) * scale
        let dy = -(p.y - svgGripCenter.y) * scale  // flip SVG y-down to SK y-up
        return CGPoint(x: dx, y: dy)
    }

    /// Local x-position of the bowstring (always vertical, fixed x).
    static func svgBowStringX(scale: CGFloat) -> CGFloat {
        (107.2 - svgGripCenter.x) * scale
    }

    private static func svgBowLimbPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: svgToLocal(CGPoint(x: 107.2, y: 341.465), scale: scale))
        path.addCurve(
            to: svgToLocal(CGPoint(x: 107.2, y: 52.5315), scale: scale),
            control1: svgToLocal(CGPoint(x: 201, y: 275.798), scale: scale),
            control2: svgToLocal(CGPoint(x: 201, y: 118.198), scale: scale)
        )
        return path
    }

    private static func svgBowStringPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: svgToLocal(CGPoint(x: 107.2, y: 341.465), scale: scale))
        path.addLine(to: svgToLocal(CGPoint(x: 107.2, y: 52.5315), scale: scale))
        return path
    }

    /// Faithful transcription of the SVG grip's complex path.
    private static func svgBowGripPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            svgToLocal(CGPoint(x: x, y: y), scale: scale)
        }
        path.move(to: P(153.302, 223.258))
        path.addLine(to: P(178.762, 223.258))   // H
        path.addCurve(
            to: P(189.482, 212.751),
            control1: P(184.682, 223.258),
            control2: P(189.482, 218.554)
        )
        path.addLine(to: P(188.27, 196.991))    // L
        path.addLine(to: P(189.482, 181.231))   // L
        path.addCurve(
            to: P(178.762, 170.724),
            control1: P(189.482, 175.428),
            control2: P(184.682, 170.724)
        )
        path.addLine(to: P(153.302, 170.724))   // H
        path.addCurve(
            to: P(157.322, 193.051),
            control1: P(147.381, 170.724),
            control2: P(157.322, 187.248)
        )
        path.addLine(to: P(157.322, 201.588))   // V
        path.addCurve(
            to: P(153.302, 223.258),
            control1: P(157.322, 207.39),
            control2: P(147.381, 223.258)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Arrow (Arrow.svg geometry)

    /// Builds an arrow node centered at (0,0), pointing right (+x). Scaled
    /// by `scale` so the same builder works for the resting arrow on the
    /// bow and the in-flight arrow. Geometry matches Arrow.svg: the point
    /// and each fletching are 4-vertex kite shapes (tip, top, inner notch,
    /// bottom), not plain triangles.
    private func makeArrowNode(scale: CGFloat) -> SKNode {
        let group = SKNode()

        let shaftLength: CGFloat = Self.arrowBaseShaft * scale
        // SVG ratios: point 14% of shaft, fletch 10%, shaft stroke 4%.
        let pointLength: CGFloat = shaftLength * 0.16
        let pointHalfWidth: CGFloat = shaftLength * 0.07
        let fletchLength: CGFloat = shaftLength * 0.13
        let fletchHalfWidth: CGFloat = shaftLength * 0.10

        let halfLen = shaftLength / 2

        // Shaft — cream stroke
        let shaftPath = CGMutablePath()
        shaftPath.move(to: CGPoint(x: -halfLen, y: 0))
        shaftPath.addLine(to: CGPoint(x: halfLen - pointLength * 0.6, y: 0))
        let shaft = SKShapeNode(path: shaftPath)
        shaft.strokeColor = Self.arrowShaftCream
        shaft.lineWidth = max(shaftLength * 0.06, 1.4)
        shaft.lineCap = .round
        group.addChild(shaft)

        // Point — 4-vertex kite: tip → top → inner notch → bottom.
        // SVG notch is ~73% back from the tip.
        let pointPath = CGMutablePath()
        pointPath.move(to: CGPoint(x: halfLen, y: 0))                                    // tip
        pointPath.addLine(to: CGPoint(x: halfLen - pointLength,         y: -pointHalfWidth))  // top
        pointPath.addLine(to: CGPoint(x: halfLen - pointLength * 0.73,  y: 0))                // notch
        pointPath.addLine(to: CGPoint(x: halfLen - pointLength,         y: pointHalfWidth))   // bottom
        pointPath.closeSubpath()
        let point = SKShapeNode(path: pointPath)
        point.fillColor = Self.arrowPointRed
        point.strokeColor = Self.arrowPointRed
        point.lineWidth = 0.5
        group.addChild(point)

        // Outer fletching — kite pointing back. SVG notch ~60% back.
        let fletchOuter = CGMutablePath()
        fletchOuter.move(to: CGPoint(x: -halfLen, y: 0))                                       // tip (toward shaft)
        fletchOuter.addLine(to: CGPoint(x: -halfLen - fletchLength,        y: -fletchHalfWidth))  // top
        fletchOuter.addLine(to: CGPoint(x: -halfLen - fletchLength * 0.6,  y: 0))                 // notch
        fletchOuter.addLine(to: CGPoint(x: -halfLen - fletchLength,        y: fletchHalfWidth))   // bottom
        fletchOuter.closeSubpath()
        let fletchOuterNode = SKShapeNode(path: fletchOuter)
        fletchOuterNode.fillColor = Self.fletchOuterRed
        fletchOuterNode.strokeColor = Self.fletchOuterRed
        fletchOuterNode.lineWidth = 0.5
        group.addChild(fletchOuterNode)

        // Inner fletching — smaller, layered on top of the outer.
        let innerLen = fletchLength * 0.55
        let innerHalfW = fletchHalfWidth * 0.55
        let fletchInner = CGMutablePath()
        fletchInner.move(to: CGPoint(x: -halfLen, y: 0))
        fletchInner.addLine(to: CGPoint(x: -halfLen - innerLen,         y: -innerHalfW))
        fletchInner.addLine(to: CGPoint(x: -halfLen - innerLen * 0.95,  y: 0))
        fletchInner.addLine(to: CGPoint(x: -halfLen - innerLen,         y: innerHalfW))
        fletchInner.closeSubpath()
        let fletchInnerNode = SKShapeNode(path: fletchInner)
        fletchInnerNode.fillColor = Self.fletchInnerRed
        fletchInnerNode.strokeColor = Self.fletchInnerRed
        fletchInnerNode.lineWidth = 0.5
        group.addChild(fletchInnerNode)

        return group
    }

    // MARK: - Target + pin

    private func buildTarget() {
        let center = transform.scenePoint(
            world: CGPoint(x: scenario.targetDistance, y: scenario.bullseyeHeight)
        )
        // Bullseye radius driven by the world tolerance (so hit-detection
        // visually matches), but cap it so the y-stretch doesn't make the
        // ring fill half the screen.
        let bullseyeRadiusPx = min(
            max(transform.sceneDistanceY(world: scenario.bullseyeRadius), 6),
            14
        )
        let outerRadiusPx = max(bullseyeRadiusPx * 2.5, 22)

        // Support post — rises from the figure's feet line up to the
        // target's bottom edge so the target visually sits on the ground.
        let postPath = CGMutablePath()
        let postBottom = CGPoint(x: center.x, y: feetScene.y)
        postPath.move(to: postBottom)
        postPath.addLine(to: CGPoint(x: center.x, y: center.y - outerRadiusPx))
        let post = SKShapeNode(path: postPath)
        post.strokeColor = Self.midGrey
        post.lineWidth = 2 * cosmeticScale
        addChild(post)

        let group = SKNode()
        let radii: [CGFloat] = [outerRadiusPx, outerRadiusPx * 0.7, outerRadiusPx * 0.4]
        for (i, radius) in radii.enumerated() {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.position = center
            ring.fillColor = .clear
            ring.strokeColor = .white.withAlphaComponent(0.45 + CGFloat(i) * 0.15)
            ring.lineWidth = 1 * cosmeticScale
            group.addChild(ring)
        }
        let bullseye = SKShapeNode(circleOfRadius: bullseyeRadiusPx)
        bullseye.position = center
        bullseye.fillColor = UIColor.white.withAlphaComponent(0.18)
        bullseye.strokeColor = .white
        bullseye.lineWidth = 1.5 * cosmeticScale
        group.addChild(bullseye)

        addChild(group)
        targetNode = group
    }

    private func buildPin() {
        let center = transform.scenePoint(
            world: CGPoint(x: scenario.targetDistance, y: scenario.bullseyeHeight)
        )
        let pin = SKShapeNode(circleOfRadius: 3 * cosmeticScale)
        pin.position = center
        pin.fillColor = .white
        pin.strokeColor = .white
        addChild(pin)
        pinNode = pin
    }

    // MARK: - Flight arrow + trail

    private func buildFlightArrow() {
        // Independent arrow that the sim drives — separate from the
        // bow-attached resting arrow so we don't reparent on every shot.
        // Same scale as the resting arrow so the arrow that leaves the
        // bow is visually the same object the user just saw nocked.
        let arrowGroup = makeArrowNode(scale: arrowScale)
        arrowGroup.position = transform.scenePoint(world: CGPoint(x: 0, y: scenario.releaseHeight))
        arrowGroup.isHidden = true
        addChild(arrowGroup)
        flightArrowNode = arrowGroup
    }

    private func buildTrail() {
        let trail = SKShapeNode()
        trail.strokeColor = UIColor.white.withAlphaComponent(0.65)
        trail.lineWidth = 1.5 * cosmeticScale
        trail.fillColor = .clear
        addChild(trail)
        trailNode = trail
    }

    private func updateFlightArrowVisual() {
        flightArrowNode?.position = transform.scenePoint(world: simPosition)
        guard isSimulating, simVelocity.dx != 0 || simVelocity.dy != 0 else { return }
        let screenDx = simVelocity.dx * Double(transform.xScale)
        let screenDy = simVelocity.dy * Double(transform.yScale)
        let baseAngle = atan2(screenDy, screenDx)

        // Archer's-paradox wobble: a damped sine-wave rotation around the
        // velocity direction. Amplitude scales with spine mismatch;
        // mismatch=0 → no wobble (Ch1 scenarios). Decays fast enough that
        // a matched arrow recovers straight before impact.
        let wobble = wobbleAngle()
        flightArrowNode?.zRotation = CGFloat(baseAngle + wobble)
    }

    private func wobbleAngle() -> Double {
        let mismatch = activeSpineMismatch
        guard abs(mismatch) > 0.01 else { return 0 }
        return wobbleAt(time: flightElapsedTime, mismatch: mismatch)
    }

    /// The visible flex angle (rad) at any sim time, given the spine
    /// mismatch driving the shot. Pulled out so the play view can predict
    /// "wobble at impact" for correctness resolution.
    private func wobbleAt(time t: Double, mismatch: Double) -> Double {
        // Amplitude scaling — mismatch=25 gives ~14° peak at release,
        // clearly visible as flex throughout flight. mismatch=10 stays
        // gentle and damps to under 3° by impact (the "clean" threshold).
        let amplitude = (mismatch / 100.0) * Self.wobbleAmplitudeRad
        let frequency = 8.0
        let decay = exp(-t / Self.wobbleDampingTau)
        return amplitude * cos(2 * .pi * frequency * t) * decay
    }

    /// Peak (envelope) wobble magnitude at a given sim time — uses the
    /// damped exponential without the oscillation term. This is what
    /// determines clean vs wobbled at impact.
    private func wobbleEnvelope(at t: Double, mismatch: Double) -> Double {
        let amplitude = (mismatch / 100.0) * Self.wobbleAmplitudeRad
        return abs(amplitude) * exp(-t / Self.wobbleDampingTau)
    }

    /// Maximum wobble amplitude (radians) at full-scale mismatch=100.
    /// 1.0 rad ≈ 57° — extreme tumble. Realistic range is mismatch ~5–40,
    /// giving 0.05–0.40 rad peaks (3°–23°) → reads clearly as flex.
    private static let wobbleAmplitudeRad: Double = 1.0

    /// Damping time constant. wobble decays to ~exp(-1)=37% in this many
    /// sim-seconds. Tuned so a moderate mismatch survives to impact at
    /// 0.5 s and a small mismatch dies by then.
    private static let wobbleDampingTau: Double = 0.55

    /// Driving mismatch for the current shot. Defaults to the scenario's
    /// configured value; compute mode overrides this when the user picks
    /// a different SPINE.
    private var activeSpineMismatch: Double = 0

    private func updateTrailVisual() {
        guard let trailNode, trailPoints.count > 1 else {
            trailNode?.path = nil
            return
        }
        let path = CGMutablePath()
        let scenePts = trailPoints.map { transform.scenePoint(world: $0) }
        path.move(to: scenePts[0])
        for point in scenePts.dropFirst() {
            path.addLine(to: point)
        }
        trailNode.path = path
    }

    // MARK: - Arrow base sizing

    /// Base shaft length when arrow scale = 1.0. The whole arrow's
    /// proportions (point, fletch, stroke) scale from this.
    private static let arrowBaseShaft: CGFloat = 50

    // MARK: - Colors (sampled from the SVG pack)

    private static let midGrey = UIColor(white: 0x6B / 255.0, alpha: 1)
    private static let borderGrey = UIColor(white: 0x3A / 255.0, alpha: 1)
    private static let bowGripOrange = UIColor(red: 1.0, green: 96/255, blue: 17/255, alpha: 1)
    private static let bowStringOrange = UIColor(red: 0xDB/255.0, green: 0x54/255.0, blue: 0x0C/255.0, alpha: 1)
    private static let arrowShaftCream = UIColor(red: 1.0, green: 0xF2/255, blue: 0xE6/255, alpha: 1)
    private static let arrowPointRed = UIColor(red: 0xE6/255, green: 0x2D/255, blue: 0x08/255, alpha: 1)
    private static let fletchOuterRed = UIColor(red: 1.0, green: 0x2C/255, blue: 0x2C/255, alpha: 1)
    private static let fletchInnerRed = UIColor(red: 1.0, green: 0x3D/255, blue: 0x00/255, alpha: 1)
}

/// Non-uniform world→scene transform. The arrow's vertical drop is ~2% of
/// horizontal flight — a uniform scale would compress it past visibility.
private struct ArcheryTransform {
    let sceneSize: CGSize
    let uiReserve: SceneInsets
    let worldXMin: Double
    let worldXMax: Double
    let worldYMin: Double
    let worldYMax: Double
    let horizontalMargin: CGFloat = 12
    let verticalMargin: CGFloat = 8

    var xScale: CGFloat {
        // `right`/`left` reserve a side band (iPad landscape dock); both default
        // to 0 so portrait geometry is unchanged.
        let usable = sceneSize.width - 2 * horizontalMargin - uiReserve.left - uiReserve.right
        return max(usable, 1) / CGFloat(worldXMax - worldXMin)
    }

    var yScale: CGFloat {
        let usable = sceneSize.height - uiReserve.top - uiReserve.bottom - 2 * verticalMargin
        return max(usable, 1) / CGFloat(worldYMax - worldYMin)
    }

    func scenePoint(world: CGPoint) -> CGPoint {
        let x = horizontalMargin + uiReserve.left + (world.x - CGFloat(worldXMin)) * xScale
        let y = uiReserve.bottom + verticalMargin + (world.y - CGFloat(worldYMin)) * yScale
        return CGPoint(x: x, y: y)
    }

    func sceneDistanceY(world: Double) -> CGFloat {
        CGFloat(world) * yScale
    }
}
