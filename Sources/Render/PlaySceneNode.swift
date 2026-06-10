import SpriteKit
import SwiftUI
import UIKit

/// SpriteKit scene for SCENARIO PLAY — the only SpriteKit instance in the app.
final class PlaySceneNode: SKScene {

    private let projectileParams: Projectile2DParams
    private var transform: CourtCoordinateTransform!

    /// UI bands occluding the scene; pushed from SwiftUI via applyUIReserve.
    private(set) var uiReserve: SceneInsets = .zero

    private var ballNode: SKShapeNode!
    private var playerSilhouette: SKShapeNode!
    private var playerHeadNode: SKShapeNode?
    private var angleIndicatorNode: SKShapeNode?
    private var trajectoryNode: SKShapeNode?

    private var backgroundLayer: SKNode?

    private var dribbleArmNode: SKShapeNode?
    private var dribbleBallShadowNode: SKShapeNode?

    private var netNode: SKShapeNode?
    private var netRimHalfWidth: CGFloat = 0
    private var netBottomY: CGFloat = 0
    private var netRimY: CGFloat = 0
    private var netCenterX: CGFloat = 0

    private let teamAccent = UIColor(red: 0.898, green: 0.447, blue: 0.165, alpha: 1.0)

    /// Injected at scene mount; nil makes every audio callback a no-op.
    var audio: AudioService?

    /// Ensures we play the rim-hit sound only once per shot, not every overlapping frame.
    private var didFireRimHitThisShot: Bool = false

    /// Cached so we can re-render the indicator after didChangeSize wipes children.
    private var lastAngleDegrees: Double?

    /// Cached so we can re-render miss arcs after didChangeSize wipes children.
    private var lastGhostTrajectory: [CGPoint]?

    private let module = Projectile2DModule()

    /// nil when scene is in IDLE.
    private var currentState: ProjectileState?

    /// Fixed-timestep accumulator (Gaffer "Fix Your Timestep").
    private var accumulator: Double = 0
    private var lastUpdateTime: TimeInterval = 0

    private(set) var snapshotHistory: [ProjectileSnapshot] = []

    private var isSimulating: Bool = false

    /// Suppresses IDLE dribble during OUTCOME (player just shot — no bounce).
    private var isShowingOutcome: Bool = false

    /// Held-breath rule: keep simulating until physical settle OR 400ms after seal.
    private var outcomeSealedAt: Double?
    private var sealedOutcome: ProjectileOutcome?

    var onOutcomeResolved: ((ProjectileOutcome, [ProjectileSnapshot]) -> Void)?

    /// Call-first beat hook — fires once when the ball reaches its apex
    /// (vertical velocity crosses from positive to negative). At that moment
    /// the simulation pauses; resume with `resumeAfterApex()`.
    var onReachedApex: (() -> Void)?

    /// When true, simulation halts at apex and waits for `resumeAfterApex()`.
    /// Default false to preserve v1's "run-to-completion" behavior.
    private(set) var pauseAtApex: Bool = false

    /// Set after the ball passes apex; prevents re-triggering the freeze.
    private var didFreezeAtApex: Bool = false

    /// Multiplier for hardcoded cosmetic pixel constants (stroke widths, label
    /// font sizes) so they don't render as hairlines / tiny text on a large
    /// iPad canvas. Derived from the smaller scene dimension vs the iPhone
    /// baseline (~393pt) these constants were tuned at; never shrinks below
    /// 1.0, capped so iPad isn't cartoonish. Uses `min(w,h)` so a wide
    /// landscape canvas doesn't inflate strokes.
    var cosmeticScale: CGFloat {
        min(max(min(size.width, size.height) / 393, 1.0), 2.2)
    }

    init(projectileParams: Projectile2DParams, size: CGSize) {
        self.projectileParams = projectileParams
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = .black
        self.anchorPoint = CGPoint(x: 0, y: 0)
        rebuildTransform(for: size)
        buildSceneGraph()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        // SwiftUI's SpriteView may hand us a different size than init-time.
        if view.bounds.size != .zero, view.bounds.size != size {
            size = view.bounds.size
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PlaySceneNode does not support init(coder:)")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != .zero else { return }
        rebuildTransform(for: size)
        repositionNodes()
    }

    private func rebuildTransform(for size: CGSize) {
        let world = projectileParams.world
        // Cap visible y at 4.5m — simulation uses real yMax for out-of-bounds,
        // but rendering crops here so the hoop (at 3.05m) sits ~68% up the
        // unoccluded band rather than getting squeezed at the top of a 6m world.
        let visualYMax = min(world.yMax, 4.5)
        transform = CourtCoordinateTransform(
            sceneSize: size,
            worldXMin: world.xMin,
            worldXMax: world.xMax,
            worldFloorY: world.floorY,
            worldYMax: visualYMax,
            uiReserve: uiReserve
        )
    }

    // MARK: - Pick-the-spot marker

    private var spotMarkerNode: SKNode?
    private var spotMarkerDistance: Double?

    /// Place (or move) the player's landing-spot marker: an accent chevron
    /// on the floor with a hairline rising to hoop height at distance `d`
    /// from the release point. nil removes it.
    func setSpotMarker(distanceMeters: Double?) {
        spotMarkerNode?.removeFromParent()
        spotMarkerNode = nil
        spotMarkerDistance = distanceMeters
        guard let d = distanceMeters, transform != nil else { return }

        let worldX = projectileParams.releasePosition[0] + d
        let floor = transform.scenePoint(world: CGPoint(x: worldX, y: CGFloat(projectileParams.world.floorY)))
        let targetHeight = transform.scenePoint(world: CGPoint(x: worldX, y: CGFloat(projectileParams.target.center[1])))

        let container = SKNode()

        let hairline = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: floor)
        path.addLine(to: targetHeight)
        hairline.path = path
        hairline.strokeColor = teamAccent.withAlphaComponent(0.45)
        hairline.lineWidth = 1
        container.addChild(hairline)

        let chevron = SKShapeNode()
        let tip = CGMutablePath()
        let size: CGFloat = 7 * cosmeticScale
        tip.move(to: CGPoint(x: floor.x - size, y: floor.y - size * 1.4))
        tip.addLine(to: CGPoint(x: floor.x, y: floor.y))
        tip.addLine(to: CGPoint(x: floor.x + size, y: floor.y - size * 1.4))
        tip.closeSubpath()
        chevron.path = tip
        chevron.fillColor = teamAccent
        chevron.strokeColor = .clear
        container.addChild(chevron)

        container.zPosition = 30
        addChild(container)
        spotMarkerNode = container
    }

    /// Push reserved UI bands from SwiftUI. Deferred mid-simulation —
    /// repositionNodes() would tear down the in-flight scene graph.
    func applyUIReserve(top: CGFloat, bottom: CGFloat, safeTop: CGFloat, safeBottom: CGFloat, right: CGFloat = 0) {
        let new = SceneInsets(top: top, bottom: bottom, safeTop: safeTop, safeBottom: safeBottom, right: right)
        guard new != uiReserve else { return }
        if isSimulating { return }
        uiReserve = new
        guard size != .zero else { return }
        rebuildTransform(for: size)
        repositionNodes()
    }

    private func buildSceneGraph() {
        addAtmosphericBackground()
        addCourtFloor()
        addHoopAndBackboard()
        addPlayerSilhouette()
        addBall()
        if isShowingOutcome {
            // OUTCOME — player has just shot; no dribble ball at the hand.
            dribbleBallShadowNode?.isHidden = true
        } else {
            startIdleDribbleIfNeeded()
        }
    }

    private func addAtmosphericBackground() {
        let layer = SKNode()
        layer.zPosition = -10

        // Fake a vertical gradient with stacked thin rectangles — SKShapeNode has no CGGradient.
        // Stripe count scales with height so the gradient stays smooth on a tall
        // iPad canvas; iPhone stays at the 24 baseline (393/36 < 24).
        let stripeCount = max(24, Int(size.height / 36))
        let stripeHeight = size.height / CGFloat(stripeCount)
        for i in 0..<stripeCount {
            let stripe = SKShapeNode(rectOf: CGSize(width: size.width, height: stripeHeight + 1))
            stripe.position = CGPoint(
                x: size.width / 2,
                y: size.height - (CGFloat(i) + 0.5) * stripeHeight
            )
            let t = pow(1.0 - CGFloat(i) / CGFloat(stripeCount - 1), 2.0)
            let alpha = 0.02 + 0.10 * t
            stripe.fillColor = UIColor(white: 1.0, alpha: alpha)
            stripe.strokeColor = .clear
            layer.addChild(stripe)
        }

        let shaft = SKShapeNode()
        let shaftPath = CGMutablePath()
        let topRight = CGPoint(x: size.width + 40, y: size.height)
        let topLeft = CGPoint(x: size.width * 0.55, y: size.height)
        let bottomLeft = CGPoint(x: size.width * 0.20, y: size.height * 0.20)
        let bottomRight = CGPoint(x: size.width * 0.65, y: size.height * 0.20)
        shaftPath.move(to: topRight)
        shaftPath.addLine(to: topLeft)
        shaftPath.addLine(to: bottomLeft)
        shaftPath.addLine(to: bottomRight)
        shaftPath.closeSubpath()
        shaft.path = shaftPath
        shaft.fillColor = UIColor(white: 1.0, alpha: 0.04)
        shaft.strokeColor = .clear
        layer.addChild(shaft)

        let floorY = transform.scenePoint(world: CGPoint(x: 0, y: CGFloat(projectileParams.world.floorY))).y
        let reflectionHeight: CGFloat = 60 * cosmeticScale
        let reflection = SKShapeNode(rectOf: CGSize(width: size.width, height: reflectionHeight))
        reflection.position = CGPoint(x: size.width / 2, y: floorY + reflectionHeight / 4)
        reflection.fillColor = UIColor(white: 1.0, alpha: 0.025)
        reflection.strokeColor = .clear
        layer.addChild(reflection)

        addChild(layer)
        backgroundLayer = layer
    }

    private func repositionNodes() {
        removeAllChildren()
        buildSceneGraph()
        if let distance = spotMarkerDistance {
            setSpotMarker(distanceMeters: distance)
        }
        if let degrees = lastAngleDegrees {
            updateAngleIndicator(degrees: degrees)
        }
        if !snapshotHistory.isEmpty {
            if let ghost = lastGhostTrajectory {
                renderMissArcs(ghostTrajectory: ghost)
            } else {
                renderTrajectoryTrail()
            }
            if let last = snapshotHistory.last {
                ballNode?.position = transform.scenePoint(world: last.ballPosition)
            }
        }
    }

    private func addCourtFloor() {
        // Floor stretches edge-to-edge of the visible scene so the player and
        // hoop read as standing on the same court — not the world's xMin→xMax
        // (which would leave gaps to the screen edges).
        let floorY = transform.scenePoint(world: CGPoint(x: 0, y: CGFloat(projectileParams.world.floorY))).y

        let floor = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: floorY))
        path.addLine(to: CGPoint(x: size.width, y: floorY))
        floor.path = path
        floor.strokeColor = UIColor(white: 1.0, alpha: 0.55)
        floor.lineWidth = 1.5 * cosmeticScale
        addChild(floor)

        // Orange free-throw accent under the player's release position only.
        let release = projectileParams.releasePosition
        let releaseX = transform.scenePoint(world: CGPoint(x: CGFloat(release[0]), y: 0)).x
        let accent = SKShapeNode()
        let accentPath = CGMutablePath()
        accentPath.move(to: CGPoint(x: releaseX - 40, y: floorY))
        accentPath.addLine(to: CGPoint(x: releaseX + 40, y: floorY))
        accent.path = accentPath
        accent.strokeColor = teamAccent.withAlphaComponent(0.75)
        accent.lineWidth = 3 * cosmeticScale
        addChild(accent)
    }

    private func addHoopAndBackboard() {
        let hoop = projectileParams.target
        let floorY = transform.scenePoint(world: CGPoint(x: 0, y: CGFloat(projectileParams.world.floorY))).y

        if let backboard = hoop.backboard {
            let bbCenter = transform.scenePoint(world: CGPoint(x: CGFloat(backboard.position[0]), y: CGFloat(backboard.position[1])))
            // JSON.height is physical vertical extent; we use it as the visual board width.
            let visualBoardWidth = transform.sceneDistance(world: backboard.height)
            let visualBoardHeight = transform.sceneDistance(world: 0.60)

            // Mounting pole — thin vertical line from floor to bottom of board.
            // Sits behind the board (lower zPosition) so the board overlaps the
            // pole's top cleanly. Anchored at bbCenter.x (back of the hoop).
            let poleBottom = CGPoint(x: bbCenter.x, y: floorY)
            let poleTop = CGPoint(x: bbCenter.x, y: bbCenter.y - visualBoardHeight / 2)
            let pole = SKShapeNode()
            let polePath = CGMutablePath()
            polePath.move(to: poleBottom)
            polePath.addLine(to: poleTop)
            pole.path = polePath
            pole.strokeColor = UIColor(white: 1.0, alpha: 0.45)
            pole.lineWidth = 3 * cosmeticScale
            pole.zPosition = -0.1
            addChild(pole)

            let outerNode = SKShapeNode(rectOf: CGSize(width: visualBoardWidth, height: visualBoardHeight))
            outerNode.position = bbCenter
            outerNode.fillColor = UIColor(white: 1.0, alpha: 0.18)
            outerNode.strokeColor = UIColor(white: 1.0, alpha: 0.85)
            outerNode.lineWidth = 2 * cosmeticScale
            addChild(outerNode)

            let innerW = visualBoardWidth * 0.40
            let innerH = visualBoardHeight * 0.55
            let inner = SKShapeNode(rectOf: CGSize(width: innerW, height: innerH))
            inner.position = CGPoint(x: bbCenter.x, y: bbCenter.y - visualBoardHeight * 0.10)
            inner.fillColor = .clear
            inner.strokeColor = UIColor(white: 1.0, alpha: 0.85)
            inner.lineWidth = 1.5 * cosmeticScale
            addChild(inner)
        }

        let hoopCenter = transform.scenePoint(world: CGPoint(x: CGFloat(hoop.center[0]), y: CGFloat(hoop.center[1])))
        // 1.4× visual bump; physics still uses the real innerRadius.
        let visualRimHalfWidth = transform.sceneDistance(world: hoop.innerRadius) * 1.4

        // Shallow ellipse gives the rim a slight from-below perspective.
        let rimEllipse = SKShapeNode(ellipseOf: CGSize(
            width: visualRimHalfWidth * 2,
            height: visualRimHalfWidth * 0.5
        ))
        rimEllipse.position = hoopCenter
        rimEllipse.fillColor = .clear
        rimEllipse.strokeColor = UIColor(white: 1.0, alpha: 0.95)
        rimEllipse.lineWidth = 3 * cosmeticScale
        addChild(rimEllipse)

        let netLength = transform.sceneDistance(world: 0.5)
        let netBottom = CGPoint(x: hoopCenter.x, y: hoopCenter.y - netLength)

        netRimHalfWidth = visualRimHalfWidth
        netBottomY = netBottom.y
        netRimY = hoopCenter.y
        netCenterX = hoopCenter.x

        let net = SKShapeNode()
        net.path = netPath(narrowness: 0.3)
        net.strokeColor = UIColor(white: 1.0, alpha: 0.65)
        net.lineWidth = 1.5 * cosmeticScale
        net.name = "net"
        addChild(net)
        netNode = net
    }

    /// Build the net's CGPath; narrowness 0 = straight down, 1 = pinched to a point.
    private func netPath(narrowness: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let pinch = netRimHalfWidth * (1 - narrowness * 0.7)
        let strands = 6
        for i in 0..<strands {
            let t = CGFloat(i) / CGFloat(strands - 1)
            let rimX = netCenterX + (t - 0.5) * 2 * netRimHalfWidth
            let bottomX = netCenterX + (t - 0.5) * 2 * pinch
            path.move(to: CGPoint(x: rimX, y: netRimY))
            path.addLine(to: CGPoint(x: bottomX, y: netBottomY))
        }
        return path
    }

    private func addPlayerSilhouette() {
        let release = projectileParams.releasePosition
        let releasePoint = transform.scenePoint(world: CGPoint(x: CGFloat(release[0]), y: CGFloat(release[1])))
        let floorY = transform.scenePoint(world: CGPoint(x: 0, y: CGFloat(projectileParams.world.floorY))).y

        let totalHeight = transform.sceneDistance(world: 1.85)
        let shoulderWidth = transform.sceneDistance(world: 0.55)
        let waistWidth = transform.sceneDistance(world: 0.34)
        let footWidth = transform.sceneDistance(world: 0.44)
        let headRadius = transform.sceneDistance(world: 0.13)

        let shoulderY = floorY + totalHeight * 0.80
        let waistY = floorY + totalHeight * 0.52
        let headCenterY = floorY + totalHeight * 0.92
        let centerX = releasePoint.x

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: centerX + footWidth / 2, y: floorY))
        bodyPath.addQuadCurve(
            to: CGPoint(x: centerX + waistWidth / 2, y: waistY),
            control: CGPoint(x: centerX + waistWidth * 0.4, y: floorY + totalHeight * 0.32)
        )
        bodyPath.addQuadCurve(
            to: CGPoint(x: centerX + shoulderWidth / 2, y: shoulderY),
            control: CGPoint(x: centerX + waistWidth / 2, y: floorY + totalHeight * 0.68)
        )
        bodyPath.addLine(to: CGPoint(x: centerX - shoulderWidth / 2, y: shoulderY))
        bodyPath.addQuadCurve(
            to: CGPoint(x: centerX - waistWidth / 2, y: waistY),
            control: CGPoint(x: centerX - waistWidth / 2, y: floorY + totalHeight * 0.68)
        )
        bodyPath.addQuadCurve(
            to: CGPoint(x: centerX - footWidth / 2, y: floorY),
            control: CGPoint(x: centerX - waistWidth * 0.4, y: floorY + totalHeight * 0.32)
        )
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = UIColor(white: 0.45, alpha: 1.0)
        body.strokeColor = .clear
        addChild(body)

        // Head as a separate node — tracing it inside the body path produced an unreadable blob.
        let head = SKShapeNode(ellipseOf: CGSize(width: headRadius * 1.7, height: headRadius * 2.0))
        head.position = CGPoint(x: centerX, y: headCenterY)
        head.fillColor = UIColor(white: 0.45, alpha: 1.0)
        head.strokeColor = .clear
        addChild(head)
        playerHeadNode = head

        // Leg slit so the stance reads — otherwise the lower body is one blob.
        let legSlit = CGMutablePath()
        let slitWidth = transform.sceneDistance(world: 0.05)
        legSlit.move(to: CGPoint(x: centerX - slitWidth, y: floorY))
        legSlit.addLine(to: CGPoint(x: centerX - slitWidth * 0.4, y: waistY - 4))
        legSlit.addLine(to: CGPoint(x: centerX + slitWidth * 0.4, y: waistY - 4))
        legSlit.addLine(to: CGPoint(x: centerX + slitWidth, y: floorY))
        legSlit.closeSubpath()
        let slit = SKShapeNode(path: legSlit)
        slit.fillColor = .black
        slit.strokeColor = .clear
        slit.zPosition = body.zPosition + 0.1
        addChild(slit)

        let armLength = transform.sceneDistance(world: 0.62)
        let armThickness = transform.sceneDistance(world: 0.09)
        let armForwardOffset = transform.sceneDistance(world: 0.18)
        let shoulderPivotX = centerX + shoulderWidth * 0.30 + armForwardOffset
        let shoulderPivotY = shoulderY - 4
        let armPath = CGMutablePath()
        armPath.addRect(CGRect(x: -armThickness / 2, y: -armLength, width: armThickness, height: armLength))
        let arm = SKShapeNode(path: armPath)
        arm.position = CGPoint(x: shoulderPivotX, y: shoulderPivotY)
        arm.fillColor = UIColor(white: 0.45, alpha: 1.0)
        arm.strokeColor = .clear
        arm.zRotation = 0
        arm.zPosition = body.zPosition + 0.2
        addChild(arm)
        dribbleArmNode = arm

        let dribbleBallRadius = transform.sceneDistance(world: 0.12)
        let dribbleBall = SKShapeNode(circleOfRadius: dribbleBallRadius)
        dribbleBall.position = CGPoint(x: shoulderPivotX, y: shoulderPivotY - armLength)
        dribbleBall.fillColor = UIColor(white: 0.60, alpha: 0.95)
        dribbleBall.strokeColor = .clear
        dribbleBall.zPosition = body.zPosition + 0.3
        addChild(dribbleBall)
        dribbleBallShadowNode = dribbleBall

        playerSilhouette = body
        startIdleBreathing()
    }

    private func startIdleBreathing() {
        guard let body = playerSilhouette else { return }
        guard !UIAccessibility.isReduceMotionEnabled else {
            body.alpha = 1.0
            playerHeadNode?.alpha = 1.0
            return
        }
        let fadeDown = SKAction.fadeAlpha(to: 0.88, duration: 1.75)
        fadeDown.timingMode = .easeInEaseOut
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 1.75)
        fadeUp.timingMode = .easeInEaseOut
        let cycle = SKAction.repeatForever(SKAction.sequence([fadeDown, fadeUp]))
        body.run(cycle, withKey: "idleBreathing")
        // SKAction isn't shareable across nodes — clone it so head pulses in phase.
        playerHeadNode?.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.88, duration: 1.75),
            SKAction.fadeAlpha(to: 1.0, duration: 1.75)
        ])), withKey: "idleBreathing")
    }

    /// Re-runnable — strips stale actions and attaches fresh ones.
    private func startIdleDribbleIfNeeded() {
        guard let arm = dribbleArmNode,
              let dribbleBall = dribbleBallShadowNode else { return }
        arm.removeAction(forKey: "dribbleArm")
        dribbleBall.removeAction(forKey: "dribbleBall")

        let halfCycle = 0.333

        let armSwingForward = SKAction.rotate(toAngle: 0.17, duration: halfCycle, shortestUnitArc: true)
        armSwingForward.timingMode = .easeOut
        let armSwingBack = SKAction.rotate(toAngle: -0.17, duration: halfCycle, shortestUnitArc: true)
        armSwingBack.timingMode = .easeIn
        let armCycle = SKAction.sequence([armSwingForward, armSwingBack])
        arm.run(SKAction.repeatForever(armCycle), withKey: "dribbleArm")

        let handY = dribbleBall.position.y
        let floorY = transform.scenePoint(world: CGPoint(x: 0, y: CGFloat(projectileParams.world.floorY))).y
        let bounceFloorY = floorY + dribbleBall.frame.height / 2

        let bounceDown = SKAction.moveTo(y: bounceFloorY, duration: halfCycle)
        bounceDown.timingMode = .easeIn
        let bounceUp = SKAction.moveTo(y: handY, duration: halfCycle)
        bounceUp.timingMode = .easeOut
        let bounceCycle = SKAction.sequence([bounceDown, bounceUp])
        dribbleBall.run(SKAction.repeatForever(bounceCycle), withKey: "dribbleBall")
    }

    /// Pause IDLE dribble; hold the ball at the player's hand.
    func pauseIdleDribble() {
        dribbleArmNode?.removeAction(forKey: "dribbleArm")
        dribbleBallShadowNode?.removeAction(forKey: "dribbleBall")
        // Snap ball back to hand y (not whatever mid-bounce y it had).
        if let dribbleBall = dribbleBallShadowNode, let arm = dribbleArmNode {
            let armLength = transform.sceneDistance(world: 0.62)
            dribbleBall.position = CGPoint(x: arm.position.x, y: arm.position.y - armLength)
            dribbleBall.isHidden = false
        }
        dribbleArmNode?.zRotation = 0
    }

    /// Hide the ball entirely. Used when ACTION starts (real shooting ball replaces it).
    func hideDribbleBall() {
        dribbleBallShadowNode?.isHidden = true
    }

    func resumeIdleDribble() {
        dribbleBallShadowNode?.isHidden = false
        startIdleDribbleIfNeeded()
    }

    /// 6-frame procedural path morph (~250ms): pinch in, settle, overshoot tail.
    func playNetFlex() {
        guard let net = netNode else { return }
        let frameDuration = 0.042
        let keyframes: [CGFloat] = [0.65, 0.85, 0.55, 0.30, 0.40, 0.30]
        let actions: [SKAction] = keyframes.map { narrowness in
            SKAction.run { [weak self] in
                guard let self else { return }
                net.path = self.netPath(narrowness: narrowness)
            }
        }
        var sequence: [SKAction] = []
        for action in actions {
            sequence.append(action)
            sequence.append(SKAction.wait(forDuration: frameDuration))
        }
        net.run(SKAction.sequence(sequence))
    }

    /// Hidden during IDLE — at release height it overlaps the head and its seam reads as a minus sign.
    private func addBall() {
        let release = projectileParams.releasePosition
        let releasePoint = transform.scenePoint(world: CGPoint(x: CGFloat(release[0]), y: CGFloat(release[1])))
        let ballRadius = transform.sceneDistance(world: projectileParams.ball.radius)

        let container = SKShapeNode(circleOfRadius: ballRadius)
        container.position = releasePoint
        container.fillColor = UIColor(white: 1.0, alpha: 1.0)
        container.strokeColor = .clear

        let seam = SKShapeNode()
        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -ballRadius * 0.85, y: 0))
        seamPath.addLine(to: CGPoint(x: ballRadius * 0.85, y: 0))
        seam.path = seamPath
        seam.strokeColor = UIColor(white: 0.15, alpha: 1.0)
        seam.lineWidth = 1 * cosmeticScale
        container.addChild(seam)

        container.isHidden = true

        addChild(container)
        ballNode = container
    }

    func setBallPosition(world: CGPoint) {
        ballNode?.position = transform.scenePoint(world: world)
    }

    func resetBall() {
        let release = projectileParams.releasePosition
        ballNode?.position = transform.scenePoint(world: CGPoint(x: CGFloat(release[0]), y: CGFloat(release[1])))
    }

    /// Start a shot. `pauseAtApex: true` enables the v2.1 call-first beat —
    /// the simulation halts at the trajectory's apex and fires
    /// `onReachedApex`; call `resumeAfterApex()` to play through.
    func startSimulation(answer: ProjectileAnswer, pauseAtApex: Bool = false) {
        resetForNewShot()
        self.pauseAtApex = pauseAtApex
        self.didFreezeAtApex = false
        currentState = module.initState(params: projectileParams, answer: answer)
        if let s = currentState {
            snapshotHistory = [module.snapshot(state: s)]
        }
        isSimulating = true
        accumulator = 0
        lastUpdateTime = 0
        didFireRimHitThisShot = false
        updateAngleIndicator(degrees: nil)

        ballNode?.isHidden = false
        pauseIdleDribble()
        hideDribbleBall()  // ACTION started — real shooting ball replaces the dribble ball
        audio?.stopLoop(.dribbleLoop)
        audio?.play(.shoot)
        ballNode?.run(
            SKAction.repeatForever(SKAction.rotate(byAngle: 2 * .pi, duration: 0.4)),
            withKey: "ballSpin"
        )
        flashSceneForShoot()
    }

    /// Resume a paused-at-apex simulation. Idempotent: safe to call when
    /// not currently frozen.
    func resumeAfterApex() {
        guard pauseAtApex, didFreezeAtApex, !isSimulating else { return }
        isSimulating = true
        accumulator = 0
        lastUpdateTime = 0
        // Resume the ball's spin animation.
        ballNode?.run(
            SKAction.repeatForever(SKAction.rotate(byAngle: 2 * .pi, duration: 0.4)),
            withKey: "ballSpin"
        )
    }

    private func flashSceneForShoot() {
        let flash = SKShapeNode(rectOf: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 100
        flash.name = "shootFlash"
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.18, duration: 0.05),
            SKAction.fadeAlpha(to: 0.0, duration: 0.2),
            SKAction.removeFromParent()
        ]))
    }

    func freezeForOutcome() {
        isSimulating = false
        isShowingOutcome = true
        updateAngleIndicator(degrees: nil)
        ballNode?.removeAction(forKey: "ballSpin")
    }

    /// Repaints trajectory as crimson failed arc + dashed white ghost arc.
    func renderMissArcs(ghostTrajectory: [CGPoint]) {
        lastGhostTrajectory = ghostTrajectory

        trajectoryNode?.removeFromParent()
        childNode(withName: "ghostArc")?.removeFromParent()
        childNode(withName: "missMarker")?.removeFromParent()

        if snapshotHistory.count > 1 {
            let path = CGMutablePath()
            path.move(to: transform.scenePoint(world: snapshotHistory[0].ballPosition))
            for snap in snapshotHistory.dropFirst() {
                path.addLine(to: transform.scenePoint(world: snap.ballPosition))
            }
            let failed = SKShapeNode()
            failed.path = path
            failed.strokeColor = UIColor(red: 1.0, green: 0.188, blue: 0.216, alpha: 1.0)
            failed.lineWidth = 1.5 * cosmeticScale
            failed.name = "failedArc"
            addChild(failed)
            trajectoryNode = failed
        }

        if ghostTrajectory.count > 1 {
            let path = CGMutablePath()
            path.move(to: transform.scenePoint(world: ghostTrajectory[0]))
            for point in ghostTrajectory.dropFirst() {
                path.addLine(to: transform.scenePoint(world: point))
            }
            let dashLen = 4 * cosmeticScale
            let dashedPath = path.copy(dashingWithPhase: 0, lengths: [dashLen, dashLen])
            let ghost = SKShapeNode()
            ghost.path = dashedPath
            ghost.strokeColor = UIColor(white: 1.0, alpha: 0.5)
            ghost.lineWidth = 1 * cosmeticScale
            ghost.name = "ghostArc"
            ghost.zPosition = -1
            addChild(ghost)
        }

        if let lastPos = snapshotHistory.last?.ballPosition {
            let markerPos = transform.scenePoint(world: lastPos)
            let marker = SKLabelNode(fontNamed: "Menlo-Regular")
            marker.text = "✕"
            marker.fontSize = 18 * cosmeticScale
            marker.fontColor = .white
            marker.horizontalAlignmentMode = .center
            marker.verticalAlignmentMode = .center
            marker.position = markerPos
            marker.name = "missMarker"
            addChild(marker)
        }
    }

    func resetForNewShot() {
        isSimulating = false
        isShowingOutcome = false
        currentState = nil
        snapshotHistory.removeAll(keepingCapacity: true)
        accumulator = 0
        lastUpdateTime = 0
        outcomeSealedAt = nil
        sealedOutcome = nil
        didFireRimHitThisShot = false
        lastGhostTrajectory = nil
        trajectoryNode?.removeFromParent()
        trajectoryNode = nil
        childNode(withName: "ghostArc")?.removeFromParent()
        childNode(withName: "missMarker")?.removeFromParent()
        // Defensive — REPLAY can hit before freezeForOutcome in edge cases.
        ballNode?.removeAction(forKey: "ballSpin")
        ballNode?.zRotation = 0
        resetBall()
        ballNode?.isHidden = true
        resumeIdleDribble()
        audio?.startLoop(.dribbleLoop)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard isSimulating, var state = currentState else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let elapsed = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        // Cap to avoid spiral-of-death after a long pause (e.g. debugger break).
        accumulator += min(elapsed, 0.1)

        let dt = projectileParams.fixedDtSeconds
        let baseCount = snapshotHistory.count
        while accumulator >= dt {
            state = module.step(state: state, dt: dt)
            accumulator -= dt
            let snap = module.snapshot(state: state)
            snapshotHistory.append(snap)

            // Call-first beat: freeze at apex on the *step* the ball's
            // vertical velocity flips sign. Checked inside the inner step
            // loop because on the first update tick the accumulator can
            // catch up many steps at once — looking only at the last pair
            // of snapshots would miss the transition entirely.
            if pauseAtApex, !didFreezeAtApex, snapshotHistory.count >= 2 {
                let prev = snapshotHistory[snapshotHistory.count - 2]
                if prev.ballVelocity.dy > 0, snap.ballVelocity.dy <= 0 {
                    didFreezeAtApex = true
                    isSimulating = false
                    currentState = state
                    ballNode?.position = transform.scenePoint(world: snap.ballPosition)
                    renderTrajectoryTrail()
                    ballNode?.removeAction(forKey: "ballSpin")
                    onReachedApex?()
                    return
                }
            }
        }
        currentState = state

        let latest = snapshotHistory.last!
        ballNode?.position = transform.scenePoint(world: latest.ballPosition)

        renderTrajectoryTrail()
        _ = baseCount  // baseCount reserved for future apex-pose tweaks

        // Fire rim-hit sound once per shot, not on every overlapping frame.
        if !didFireRimHitThisShot {
            let hoop = projectileParams.target
            let dx = latest.ballPosition.x - CGFloat(hoop.center[0])
            let dy = latest.ballPosition.y - CGFloat(hoop.center[1])
            let withinRimX = abs(dx) <= CGFloat(hoop.innerRadius + projectileParams.ball.radius)
            let withinRimY = abs(dy) <= CGFloat(hoop.rimThickness)
            if withinRimX && withinRimY {
                didFireRimHitThisShot = true
                audio?.play(.rimHit)
            }
        }

        // Held-breath rule: keep stepping until resolved AND (settled OR 400ms post-decision).
        let outcome = module.evaluate(history: snapshotHistory, params: projectileParams)
        if outcome.isResolved {
            if outcomeSealedAt == nil {
                outcomeSealedAt = currentTime
                sealedOutcome = outcome
            }
            let elapsedSinceSeal = currentTime - (outcomeSealedAt ?? currentTime)
            let world = projectileParams.world
            let ballOutOfBounds = latest.ballPosition.y < world.floorY
                                || latest.ballPosition.x < world.xMin
                                || latest.ballPosition.x > world.xMax
            if ballOutOfBounds || elapsedSinceSeal >= 0.4 {
                isSimulating = false
                onOutcomeResolved?(sealedOutcome ?? outcome, snapshotHistory)
            }
        }
    }

    private func renderTrajectoryTrail() {
        trajectoryNode?.removeFromParent()
        guard snapshotHistory.count > 1 else { return }

        let path = CGMutablePath()
        path.move(to: transform.scenePoint(world: snapshotHistory[0].ballPosition))
        for snap in snapshotHistory.dropFirst() {
            path.addLine(to: transform.scenePoint(world: snap.ballPosition))
        }
        let line = SKShapeNode()
        line.path = path
        line.strokeColor = UIColor(white: 1.0, alpha: 0.7)
        line.lineWidth = 1 * cosmeticScale
        addChild(line)
        trajectoryNode = line
    }

    /// nil clears the indicator (when the field is empty).
    func updateAngleIndicator(degrees: Double?) {
        lastAngleDegrees = degrees

        angleIndicatorNode?.removeFromParent()
        angleIndicatorNode = nil
        childNode(withName: "angleLabel")?.removeFromParent()

        guard let degrees, degrees >= 0, degrees <= 90 else { return }

        let releasePoint = transform.scenePoint(
            world: CGPoint(
                x: CGFloat(projectileParams.releasePosition[0]),
                y: CGFloat(projectileParams.releasePosition[1])
            )
        )

        // Visual length only — not physics-derived.
        let indicatorLength = transform.sceneDistance(world: 1.4)
        let radians = degrees * .pi / 180
        let endpoint = CGPoint(
            x: releasePoint.x + indicatorLength * CGFloat(cos(radians)),
            y: releasePoint.y + indicatorLength * CGFloat(sin(radians))
        )

        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: releasePoint)
        path.addLine(to: endpoint)
        line.path = path
        line.strokeColor = UIColor(white: 1.0, alpha: 0.9)
        line.lineWidth = 1 * cosmeticScale
        addChild(line)
        angleIndicatorNode = line

        let label = SKLabelNode(fontNamed: "Menlo-Regular")
        label.text = "\(Int(degrees.rounded()))°"
        label.fontSize = 11 * cosmeticScale
        label.fontColor = UIColor(white: 1.0, alpha: 0.7)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: endpoint.x + 8 * cosmeticScale, y: endpoint.y)
        label.name = "angleLabel"
        addChild(label)
    }
}
