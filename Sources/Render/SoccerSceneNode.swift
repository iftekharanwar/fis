import SpriteKit
import UIKit

/// Plan-view soccer scene. Integrates Magnus-driven free-kick physics
/// every frame: the ball gets an initial velocity vector from POWER +
/// DIRECTION, then a constant lateral acceleration (Magnus, scaled to
/// land exactly `signedSpin` meters off the no-spin line) curves the
/// flight through to the goal. Replaces the earlier SwiftUI Bezier so
/// the trajectory reads like a struck ball — POWER visibly changes
/// flight time, DIRECTION sets the launch angle, SPIN sweeps the curve.
///
/// World coordinates:
///   x = lateral meters (negative = left of centre, positive = right)
///   y = forward meters (0 at the shooter, goalDistance at the goal)
final class SoccerSceneNode: SKScene {

    let scenario: SoccerScenario

    /// Sim seconds per real second. Real flight time of a 25 m / 27 m/s
    /// strike is under one second — too fast for the curve to read.
    /// 0.7 keeps the bend visible without making the shot feel slow.
    private let timeScale: Double = 0.7

    private var transform: SoccerTransform!

    /// HUD chrome reserve at the top of the scene (status bar + CallHUD
    /// + info strip). The play view passes the live value through
    /// `applyReserves(top:bottom:)` so the goal frame stays clear of
    /// the info strip.
    var topReserve: CGFloat = 60

    /// Bottom dock reserve — same idea, on the slider/stance side.
    var bottomReserve: CGFloat = 240

    /// Goalkeeper's lateral position in normalized goal-mouth units
    /// (-1 = left post, +1 = right post). Picked once per scenario
    /// load by the play view so dragging the sliders doesn't move
    /// the figure the player is trying to beat.
    var keeperOffset: Double = 0

    /// Defender wall's centre, in normalized half-width units. Picked
    /// once per scenario by the play view so the random layout stays
    /// stable while sliders move, and so the wall + keeper can be
    /// chosen coherently (opposite sides of the goal) to leave a real
    /// target the player has to find.
    var wallOffsetCentre: Double = 0

    // Static nodes
    private var pitchTintNode: SKShapeNode?
    private var goalAreaNode: SKShapeNode?
    private var centreCircleNode: SKShapeNode?
    private var goalFrameNode: SKShapeNode?
    private var shooterNode: SKSpriteNode?
    /// Current SF Symbol for the shooter. Held here so that scene-graph
    /// rebuilds (triggered by `applyReserves` on phase changes) keep
    /// whichever pose was set last — the kicking pose persists from
    /// release all the way through the verdict screen instead of
    /// snapping back to the walking pose the instant the dock resizes.
    private var currentShooterSymbol: String = "figure.walk"
    private var keeperNode: SKSpriteNode?
    private var wallNodes: [SKSpriteNode] = []
    private var teammateNode: SKSpriteNode?
    private var extraDefenderNode: SKSpriteNode?

    // Dynamic
    private var ballNode: SKShapeNode?
    private var trailNode: SKShapeNode?
    private var ghostNode: SKShapeNode?

    // Sim state — world meters
    private var simPosition: CGPoint = .zero
    private var simVelocity: CGVector = .zero
    private var lateralAccel: Double = 0
    private var isSimulating: Bool = false
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: Double = 0
    private let fixedDt: Double = 1.0 / 240.0
    private var trailPoints: [CGPoint] = []

    // Collision / bounce state. After a wall, post, or keeper hit the
    // ball keeps integrating for `bounceFramesLeft` ticks so the player
    // sees it deflect — then the queued outcome fires.
    private var pendingBounceOutcome: SoccerOutcome? = nil
    private var bounceFramesLeft: Int = 0
    /// True after the ball has deflected off the attacking teammate at
    /// least once. Prevents a re-collision on the same body (the ball
    /// can pass back through after the deflection if the trajectory
    /// curves around).
    private var hasDeflectedOffTeammate: Bool = false

    // Pending ghost args persist across scene rebuilds (so a layout
    // change doesn't wipe the slider preview the player is reading)
    private var pendingGhostPower: Double?
    private var pendingGhostAim: Double = 0
    private var pendingGhostSpin: Double = 0

    /// Emitted from the physics resolution when the ball crosses the
    /// goal line. The play view dispatches it back to the main actor
    /// before flipping phases.
    var onOutcomeResolved: ((SoccerOutcome) -> Void)?

    init(scenario: SoccerScenario, size: CGSize, keeperOffset: Double, wallOffsetCentre: Double) {
        self.scenario = scenario
        self.keeperOffset = keeperOffset
        self.wallOffsetCentre = wallOffsetCentre
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor.black
        anchorPoint = CGPoint(x: 0, y: 0)
        rebuildTransform(for: size)
        buildSceneGraph()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SoccerSceneNode does not support init(coder:)")
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

    /// Update the HUD/dock reservations from the play view. Triggers a
    /// scene-graph rebuild so the figures + goal frame re-lay out
    /// against the new usable area.
    func applyReserves(top: CGFloat, bottom: CGFloat) {
        guard top != topReserve || bottom != bottomReserve else { return }
        topReserve = top
        bottomReserve = bottom
        rebuildTransform(for: size)
        rebuildSceneGraph()
    }

    /// Start the ball flying with the chosen Magnus parameters.
    /// - Parameters:
    ///   - power: ball muzzle velocity in m/s. Drives the forward
    ///     component and inversely controls the curve's time to act.
    ///   - aim: normalized direction (-1 = left post, +1 = right post).
    ///   - signedSpin: signed Magnus curve in meters at the goal line.
    ///     Positive bends right, negative bends left, 0 is a knuckler.
    func startSimulation(power: Double, aim: Double, signedSpin: Double) {
        clearGhost()
        let halfWidth = scenario.goalWidth / 2.0
        // Forward velocity is the bulk of the speed; aim adds a small
        // lateral component so a zero-spin shot lands at aim*halfWidth.
        let vy = power
        let T = scenario.goalDistance / vy
        let vx = aim * halfWidth / T
        // Magnus acceleration that produces exactly signedSpin meters
        // of lateral displacement past the no-spin line in time T:
        //   ½·a·T² = signedSpin  →  a = 2·signedSpin / T²
        let a = 2 * signedSpin / (T * T)

        simPosition = .zero
        simVelocity = CGVector(dx: vx, dy: vy)
        lateralAccel = a
        trailPoints = [simPosition]
        isSimulating = true
        accumulator = 0
        lastUpdateTime = 0
        pendingBounceOutcome = nil
        bounceFramesLeft = 0
        hasDeflectedOffTeammate = false

        // Flip the shooter into a kicking pose at release.
        updateShooterSymbol("figure.kickboxing")

        // Play the boot-meets-ball sound at the exact moment of strike.
        Task { @MainActor in
            AudioService.shared.play(.kickBall)
        }

        ballNode?.isHidden = false
        updateBallVisual()
        updateTrailVisual()
    }

    /// Live dashed preview of where the chosen parameters will land.
    /// Pass nil power to hide the preview.
    func setGhost(power: Double?, aim: Double, signedSpin: Double) {
        pendingGhostPower = power
        pendingGhostAim = aim
        pendingGhostSpin = signedSpin
        guard let p = power else { ghostNode?.path = nil; return }
        drawGhost(power: p, aim: aim, signedSpin: signedSpin)
    }

    func clearGhost() {
        pendingGhostPower = nil
        ghostNode?.path = nil
    }

    /// Reset state for a fresh attempt. The ball returns to the
    /// shooter, the trail clears, sim is parked.
    func resetForNewShot() {
        isSimulating = false
        simPosition = .zero
        simVelocity = .zero
        trailPoints = []
        accumulator = 0
        lastUpdateTime = 0
        pendingBounceOutcome = nil
        bounceFramesLeft = 0
        hasDeflectedOffTeammate = false
        // Return the shooter to its walking pose between attempts.
        updateShooterSymbol("figure.walk")
        ballNode?.position = transform.scenePoint(world: .zero)
        trailNode?.path = nil
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
        accumulator += min(realDt * timeScale, 0.05)

        while accumulator >= fixedDt && isSimulating {
            stepSimulation()
            accumulator -= fixedDt
        }

        updateBallVisual()
        updateTrailVisual()
    }

    private func stepSimulation() {
        let prev = simPosition

        // Integrate position
        simVelocity.dx += lateralAccel * fixedDt
        simPosition.x += simVelocity.dx * fixedDt
        simPosition.y += simVelocity.dy * fixedDt
        trailPoints.append(simPosition)

        // If a collision already happened, keep integrating during the
        // bounce window so the deflection is visible — then fire the
        // queued outcome.
        if let outcome = pendingBounceOutcome {
            bounceFramesLeft -= 1
            if bounceFramesLeft <= 0 {
                isSimulating = false
                pendingBounceOutcome = nil
                onOutcomeResolved?(outcome)
            }
            return
        }

        // Attacking teammate deflection — only on scenarios that ship
        // one. The ball doesn't STOP here, it just bounces forward at
        // a new lateral velocity so it can still find the net.
        if scenario.hasTeammate && !hasDeflectedOffTeammate {
            let teammateY = scenario.teammateDistance
            let crossedTeammate = prev.y < teammateY && simPosition.y >= teammateY
            if crossedTeammate {
                let teammateX = scenario.teammateOffset * (scenario.goalWidth / 2.0)
                if abs(simPosition.x - teammateX) < teammateHalfMeters {
                    // Reflect the lateral velocity off the teammate's
                    // body — they redirect the ball, losing some pace.
                    // Forward velocity dampens slightly. No queued
                    // outcome: the ball keeps flying toward the goal.
                    simVelocity.dx = -simVelocity.dx * 0.6
                    simVelocity.dy *= 0.92
                    hasDeflectedOffTeammate = true
                    return
                }
            }
        }

        // Extra defender (rebound chapters) — single isolated body on
        // the SAME forward line as the wall, offset to one side. Closes
        // the direct shooting angle and bounces the ball like the wall.
        if scenario.hasExtraDefender {
            let extraY = effectiveWallDistance
            let crossedExtra = prev.y < extraY && simPosition.y >= extraY
            if crossedExtra {
                let extraX = scenario.extraDefenderOffset * (scenario.goalWidth / 2.0)
                if abs(simPosition.x - extraX) < extraDefenderHalfMeters {
                    simVelocity.dy = -abs(simVelocity.dy) * 0.45
                    simVelocity.dx *= 0.6
                    scheduleBounce(.savedByKeeper, frames: 90)
                    return
                }
            }
        }

        // Wall collision — the ball cannot pass over the defenders.
        let crossedWall = prev.y < effectiveWallDistance && simPosition.y >= effectiveWallDistance
        if crossedWall && wallContains(worldX: simPosition.x) {
            // Reverse the forward velocity (ball bounces back toward the
            // shooter) and dampen the lateral component. Schedule the
            // resolved outcome to fire after the visible bounce.
            simVelocity.dy = -abs(simVelocity.dy) * 0.45
            simVelocity.dx *= 0.6
            scheduleBounce(.savedByKeeper, frames: 90)
            return
        }

        // Goal-line resolution
        let crossedGoal = prev.y < scenario.goalDistance && simPosition.y >= scenario.goalDistance
        guard crossedGoal else { return }

        let halfWidth = scenario.goalWidth / 2.0
        let landing = simPosition.x
        let postMargin = 0.18

        // Post hit — ball grazes one of the upright posts and rebounds.
        if abs(abs(landing) - halfWidth) < postMargin {
            simVelocity.dx = -simVelocity.dx * 0.55
            simVelocity.dy = -abs(simVelocity.dy) * 0.40
            scheduleBounce(.wideOfPost, frames: 90)
            return
        }

        // Past the posts entirely → wide. No bounce: nothing to hit.
        if abs(landing) >= halfWidth {
            isSimulating = false
            onOutcomeResolved?(.wideOfPost)
            return
        }

        // Keeper save — ball arrives within the keeper's reach. The ball
        // bounces off the gloves before the verdict appears.
        let keeperX = keeperOffset * halfWidth
        if abs(landing - keeperX) < keeperReachMeters {
            simVelocity.dy = -abs(simVelocity.dy) * 0.5
            simVelocity.dx *= 0.7
            scheduleBounce(.savedByKeeper, frames: 90)
            return
        }

        // Clean goal: cleared posts and keeper, struck into the net.
        isSimulating = false
        onOutcomeResolved?(.goal)
    }

    /// Queues a deferred outcome so the ball keeps animating its bounce
    /// for `frames` ticks before the verdict fires.
    private func scheduleBounce(_ outcome: SoccerOutcome, frames: Int) {
        pendingBounceOutcome = outcome
        bounceFramesLeft = frames
    }

    /// True iff a ball at `worldX` (lateral meters) is intersecting any
    /// figure in the defender wall — the three figure.stand silhouettes
    /// from `buildWall()`.
    private func wallContains(worldX: Double) -> Bool {
        let halfWidth = scenario.goalWidth / 2.0
        let centre = wallOffsetNorm * halfWidth
        // Wall spans the leftmost figure's left edge to the rightmost
        // figure's right edge, ±wallFigureHalfMeters per body.
        let leftEdge = centre - wallSpacingNorm * halfWidth - wallFigureHalfMeters
        let rightEdge = centre + wallSpacingNorm * halfWidth + wallFigureHalfMeters
        return worldX >= leftEdge && worldX <= rightEdge
    }

    /// Wall positioning. Both the visual layout (`buildWall()`) and
    /// collision check (`wallContains(...)`) read the same stored
    /// `wallOffsetCentre` so the random placement and the bounce
    /// physics never disagree.
    private var wallOffsetNorm: Double { wallOffsetCentre }
    private let wallSpacingNorm: Double = 0.13
    /// Half-width of each defender body in world meters. Scaled down
    /// to match the smaller silhouettes — bigger value = wider wall
    /// hitbox = harder to curl the ball around it.
    private let wallFigureHalfMeters: Double = 0.48

    /// Goalkeeper's lateral reach in world meters. The ball is saved
    /// if its landing offset is within `keeperReachMeters` of the
    /// keeper's position. Scaled down with the smaller keeper sprite.
    private let keeperReachMeters: Double = 0.85

    /// Half-width (in world meters) of the attacking teammate's body.
    /// Used by the deflection check in `stepSimulation` to decide if
    /// the ball strikes them on its way forward.
    private let teammateHalfMeters: Double = 0.65

    /// Half-width (in world meters) of the isolated extra defender on
    /// the rebound chapters. Slightly wider than a wall body so the
    /// player really has to route around them via the teammate.
    private let extraDefenderHalfMeters: Double = 0.75

    /// Forward distance to the wall used by BOTH the visual layout and
    /// the collision check. Adds a fixed offset to the authored
    /// `scenario.wallDistance` so the defenders sit further from the
    /// shooter on screen — gives the shot more "build-up" room without
    /// breaking the bounce physics (collision uses the same value).
    private var effectiveWallDistance: Double {
        scenario.wallDistance + 3.5
    }

    // MARK: - Scene graph

    private func rebuildTransform(for size: CGSize) {
        transform = SoccerTransform(
            sceneSize: size,
            topReserve: topReserve,
            bottomReserve: bottomReserve,
            scenario: scenario
        )
    }

    private func rebuildSceneGraph() {
        removeAllChildren()
        pitchTintNode = nil
        goalAreaNode = nil
        centreCircleNode = nil
        goalFrameNode = nil
        shooterNode = nil
        keeperNode = nil
        wallNodes.removeAll()
        teammateNode = nil
        extraDefenderNode = nil
        ballNode = nil
        trailNode = nil
        ghostNode = nil

        buildSceneGraph()

        if isSimulating {
            updateBallVisual()
            updateTrailVisual()
        }
        if let p = pendingGhostPower {
            drawGhost(power: p, aim: pendingGhostAim, signedSpin: pendingGhostSpin)
        }
    }

    private func buildSceneGraph() {
        buildPitchTint()
        buildGoalAreaLines()
        buildCentreCircle()
        buildGoalFrame()
        buildShooter()
        buildWall()
        buildKeeper()
        if scenario.hasExtraDefender {
            buildExtraDefender()
        }
        if scenario.hasTeammate {
            buildTeammate()
        }
        buildGhost()
        buildTrail()
        buildBall()
    }

    private func buildTeammate() {
        let halfWidth = scenario.goalWidth / 2.0
        let worldX = scenario.teammateOffset * halfWidth
        let worldY = scenario.teammateDistance
        // Orange silhouette so the attacking teammate reads as a
        // different agent than the white wall / keeper / shooter — the
        // colour also matches the ball's trail, hinting that this
        // figure is the rebound surface the player aims for.
        let sprite = makeFigureSprite(systemName: "figure.stand", scale: 0.95, tint: Self.rimOrange)
        sprite.position = transform.scenePoint(world: CGPoint(x: worldX, y: worldY))
        addChild(sprite)
        teammateNode = sprite
    }

    private func buildExtraDefender() {
        let halfWidth = scenario.goalWidth / 2.0
        let worldX = scenario.extraDefenderOffset * halfWidth
        // Anchored on the wall's forward line — the isolated defender
        // stands shoulder-to-shoulder with the row of three, just offset
        // to one side to seal a goal corner the wall doesn't cover.
        let worldY = effectiveWallDistance
        let sprite = makeFigureSprite(systemName: "figure.stand", scale: 0.95)
        sprite.position = transform.scenePoint(world: CGPoint(x: worldX, y: worldY))
        addChild(sprite)
        extraDefenderNode = sprite
    }

    // MARK: - Static visuals

    private func buildPitchTint() {
        let rect = CGRect(origin: .zero, size: size)
        let node = SKShapeNode(rect: rect)
        node.fillColor = Self.sceneBg
        node.strokeColor = .clear
        addChild(node)
        pitchTintNode = node
    }

    private func buildGoalAreaLines() {
        let halfWidth = scenario.goalWidth / 2.0
        let xLeft = transform.scenePoint(world: CGPoint(x: -halfWidth * 1.4, y: scenario.goalDistance)).x
        let xRight = transform.scenePoint(world: CGPoint(x: halfWidth * 1.4, y: scenario.goalDistance)).x
        let yLine = transform.scenePoint(world: CGPoint(x: 0, y: scenario.goalDistance)).y
        let yBox = transform.scenePoint(world: CGPoint(x: 0, y: scenario.goalDistance * 0.82)).y
        let path = CGMutablePath()
        path.move(to: CGPoint(x: xLeft, y: yLine))
        path.addLine(to: CGPoint(x: xLeft, y: yBox))
        path.addLine(to: CGPoint(x: xRight, y: yBox))
        path.addLine(to: CGPoint(x: xRight, y: yLine))
        let node = SKShapeNode(path: path)
        node.strokeColor = Self.borderGrey
        node.lineWidth = 1
        node.fillColor = .clear
        addChild(node)
        goalAreaNode = node
    }

    private func buildCentreCircle() {
        let r = min(size.width, size.height) * 0.05
        let centre = transform.scenePoint(world: CGPoint(x: 0, y: scenario.goalDistance / 2))
        let node = SKShapeNode(circleOfRadius: r)
        node.position = centre
        node.strokeColor = Self.borderGrey.withAlphaComponent(0.55)
        node.lineWidth = 1
        node.fillColor = .clear
        addChild(node)
        centreCircleNode = node
    }

    private func buildGoalFrame() {
        let halfWidth = scenario.goalWidth / 2.0
        let xL = transform.scenePoint(world: CGPoint(x: -halfWidth, y: scenario.goalDistance)).x
        let xR = transform.scenePoint(world: CGPoint(x: halfWidth, y: scenario.goalDistance)).x
        let yLine = transform.scenePoint(world: CGPoint(x: 0, y: scenario.goalDistance)).y
        // SpriteKit y axis grows UP, so "behind the goal line" is +y.
        let netDepth: CGFloat = size.height * 0.035
        let yBack = yLine + netDepth
        let path = CGMutablePath()
        path.move(to: CGPoint(x: xL, y: yLine))
        path.addLine(to: CGPoint(x: xL, y: yBack))
        path.addLine(to: CGPoint(x: xR, y: yBack))
        path.addLine(to: CGPoint(x: xR, y: yLine))
        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.lineWidth = 2
        node.fillColor = .clear
        addChild(node)
        goalFrameNode = node
    }

    private func buildShooter() {
        let sprite = makeFigureSprite(systemName: currentShooterSymbol, scale: 1.0)
        sprite.position = transform.scenePoint(world: .zero)
        addChild(sprite)
        shooterNode = sprite
    }

    private func buildWall() {
        let halfWidth = scenario.goalWidth / 2.0
        for i in -1...1 {
            let normX = wallOffsetNorm + Double(i) * wallSpacingNorm
            let worldX = normX * halfWidth
            let sprite = makeFigureSprite(systemName: "figure.stand", scale: 0.88)
            sprite.position = transform.scenePoint(world: CGPoint(x: worldX, y: effectiveWallDistance))
            addChild(sprite)
            wallNodes.append(sprite)
        }
    }

    private func buildKeeper() {
        let halfWidth = scenario.goalWidth / 2.0
        let worldX = keeperOffset * halfWidth
        let worldY = scenario.goalDistance * 0.96   // just inside the line
        let sprite = makeFigureSprite(systemName: "figure", scale: 0.95)
        sprite.position = transform.scenePoint(world: CGPoint(x: worldX, y: worldY))
        addChild(sprite)
        keeperNode = sprite
    }

    /// SF Symbol → tinted UIImage → SKTexture → feet-anchored sprite.
    ///
    /// The SF Symbol is tinted via `withTintColor` (white by default,
    /// orange for the attacking teammate), then drawn into an explicitly
    /// transparent bitmap so the resulting texture is just the tinted
    /// silhouette on a clear background — no surrounding frame.
    ///
    /// Anchor at (0.5, 0) so positioning the sprite at a world point
    /// puts its feet exactly there.
    private func makeFigureSprite(systemName: String, scale: CGFloat, tint: UIColor = .white) -> SKSpriteNode {
        let height = figureHeight * scale
        let config = UIImage.SymbolConfiguration(pointSize: height, weight: .regular)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: config) else {
            return SKSpriteNode()
        }
        let tinted = symbol.withTintColor(tint, renderingMode: .alwaysOriginal)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: tinted.size, format: format)
        let bitmap = renderer.image { _ in
            tinted.draw(at: .zero)
        }
        let texture = SKTexture(image: bitmap)
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }

    /// Swap the shooter's SF Symbol on the fly — used to flip the
    /// figure into a kicking pose the moment the ball is struck, and
    /// back to a walking pose between attempts.
    private func updateShooterSymbol(_ systemName: String) {
        currentShooterSymbol = systemName
        guard let existing = shooterNode else { return }
        let position = existing.position
        existing.removeFromParent()
        let sprite = makeFigureSprite(systemName: systemName, scale: 1.0)
        sprite.position = position
        addChild(sprite)
        shooterNode = sprite
    }

    private var figureHeight: CGFloat {
        // Smaller silhouettes — shooter, defenders, teammate and keeper
        // now feel like distant figures on the pitch. Hitboxes below
        // (wallFigureHalfMeters / keeperReachMeters / etc.) shrink in
        // step so the visual and the physics still agree.
        let base = min(size.width, size.height) * 0.082
        return min(max(base, 30), 46)
    }

    // MARK: - Dynamic visuals

    private func buildTrail() {
        let node = SKShapeNode()
        node.strokeColor = Self.rimOrange
        node.lineWidth = 2.2
        node.lineCap = .round
        node.lineJoin = .round
        node.fillColor = .clear
        addChild(node)
        trailNode = node
    }

    private func buildBall() {
        let r = min(size.width, size.height) * 0.0075
        let node = SKShapeNode(circleOfRadius: r)
        node.fillColor = .white
        node.strokeColor = .clear
        node.lineWidth = 0
        node.position = transform.scenePoint(world: .zero)
        addChild(node)
        ballNode = node
    }

    private func buildGhost() {
        let node = SKShapeNode()
        node.strokeColor = UIColor.white.withAlphaComponent(0.85)
        node.lineWidth = 1.6
        node.lineCap = .round
        node.lineJoin = .round
        node.fillColor = .clear
        addChild(node)
        ghostNode = node
    }

    /// Short aim indicator that sprouts from the shooter. Length scales
    /// with POWER, the initial tangent follows AIM (so the ball is
    /// always going to LEAVE the foot in the aim direction — SPIN never
    /// rotates the start), and only the tip of the indicator drifts
    /// gently with SPIN to hint that the Magnus curve is coming.
    ///
    /// Mathematically: quadratic Bezier with the control point placed
    /// on the aim line at the midpoint. That keeps the launch tangent
    /// purely aim-driven; the spin contribution shows up only past the
    /// midpoint, growing toward the indicator's end.
    private func drawGhost(power: Double, aim: Double, signedSpin: Double) {
        guard let ghost = ghostNode else { return }
        let halfWidth = scenario.goalWidth / 2.0

        // Forward offset so the indicator starts AHEAD of the shooter's
        // silhouette instead of overlapping it — gives the figure room
        // to breathe and reads as "the ball will travel forward FROM
        // here", not THROUGH the player.
        let startY: Double = 2.4
        // Forward length in world meters — scales linearly with POWER.
        // Trimmed so the indicator stays a hint, not a full preview.
        let length = power * 0.17
        // Aim contribution at the end of the indicator.
        let aimEndX = aim * halfWidth * (length / scenario.goalDistance)
        // SPIN contribution kept SUBTLE — small visual cue, not a full
        // preview of where the ball will land.
        let spinEndX = signedSpin * 0.05
        let endX = aimEndX + spinEndX

        let p0 = transform.scenePoint(world: CGPoint(x: 0, y: startY))
        let p1 = transform.scenePoint(world: CGPoint(x: aimEndX * 0.5, y: startY + length * 0.5))
        let p2 = transform.scenePoint(world: CGPoint(x: endX, y: startY + length))

        let samples = 16
        let path = CGMutablePath()
        path.move(to: p0)
        for i in 1...samples {
            let t = Double(i) / Double(samples)
            let oneMinus = 1 - t
            let x = oneMinus * oneMinus * p0.x + 2 * oneMinus * t * p1.x + t * t * p2.x
            let y = oneMinus * oneMinus * p0.y + 2 * oneMinus * t * p1.y + t * t * p2.y
            path.addLine(to: CGPoint(x: x, y: y))
        }
        // Dashed stroke — the indicator is a hint, not the real trail.
        ghost.path = path.copy(dashingWithPhase: 0, lengths: [4, 5])
    }

    private func updateBallVisual() {
        ballNode?.position = transform.scenePoint(world: simPosition)
    }

    private func updateTrailVisual() {
        guard let trail = trailNode else { return }
        guard let first = trailPoints.first else { trail.path = nil; return }
        let path = CGMutablePath()
        path.move(to: transform.scenePoint(world: first))
        for pt in trailPoints.dropFirst() {
            path.addLine(to: transform.scenePoint(world: pt))
        }
        trail.path = path
    }

    // MARK: - Colors (mirror Color+Tokens)

    private static let rimOrange = UIColor(red: 0xE8/255.0, green: 0x78/255.0, blue: 0x2B/255.0, alpha: 1)
    private static let ballShadow = UIColor(red: 0x8B/255.0, green: 0x3F/255.0, blue: 0x10/255.0, alpha: 1)
    private static let borderGrey = UIColor(red: 0x3A/255.0, green: 0x3A/255.0, blue: 0x3A/255.0, alpha: 1)
    private static let sceneBg = UIColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x18/255.0, alpha: 1)
}

// MARK: - Coordinate transform

/// Maps soccer-world meters into scene pixels. SpriteKit's y-axis grows
/// upward from the bottom, which lines up naturally with "forward
/// distance = up the page", so no axis flip is needed here.
struct SoccerTransform {
    let sceneSize: CGSize
    let topReserve: CGFloat
    let bottomReserve: CGFloat
    let scenario: SoccerScenario

    private let leftPad: CGFloat
    private let rightPad: CGFloat

    init(sceneSize: CGSize, topReserve: CGFloat, bottomReserve: CGFloat, scenario: SoccerScenario) {
        self.sceneSize = sceneSize
        self.topReserve = topReserve
        self.bottomReserve = bottomReserve
        self.scenario = scenario
        // Wider horizontal pads → the goal cage now occupies ~32% of
        // the canvas width, reading as a small distant target. The
        // pitch breathes more on either side and the whole composition
        // feels less crowded.
        self.leftPad = sceneSize.width * 0.34
        self.rightPad = sceneSize.width * 0.34
    }

    func scenePoint(world: CGPoint) -> CGPoint {
        let halfWidth = scenario.goalWidth / 2.0
        let nx = world.x / halfWidth                                // -1..+1
        let ny = world.y / scenario.goalDistance                    // 0..1
        let usableWidth = max(sceneSize.width - leftPad - rightPad, 1)
        let usableHeight = max(sceneSize.height - topReserve - bottomReserve, 1)
        let sx = leftPad + (nx + 1) / 2 * usableWidth
        let sy = bottomReserve + ny * usableHeight
        return CGPoint(x: sx, y: sy)
    }
}
