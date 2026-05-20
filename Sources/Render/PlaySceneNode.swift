import SpriteKit
import SwiftUI
import UIKit

/// SpriteKit scene for SCENARIO PLAY — the only SpriteKit instance in the app.
final class PlaySceneNode: SKScene {

    private let projectileParams: Projectile2DParams
    private var transform: CourtCoordinateTransform!

    private var ballNode: SKShapeNode!
    private var playerSilhouette: SKShapeNode!
    private var playerHeadNode: SKShapeNode?
    private var angleIndicatorNode: SKShapeNode?
    private var trajectoryNode: SKShapeNode?

    private var backgroundLayer: SKNode?

    private var dribbleArmNode: SKShapeNode?
    private var dribbleBallShadowNode: SKShapeNode?
    private var isIdleDribbling: Bool = false

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

    /// Held-breath rule: keep simulating until physical settle OR 400ms after seal.
    private var outcomeSealedAt: Double?
    private var sealedOutcome: ProjectileOutcome?

    var onOutcomeResolved: ((ProjectileOutcome, [ProjectileSnapshot]) -> Void)?

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
        // Use full world yMax — cropping clips feet at bottom and floats the floor accent.
        transform = CourtCoordinateTransform(
            sceneSize: size,
            worldXMin: world.xMin,
            worldXMax: world.xMax,
            worldFloorY: world.floorY,
            worldYMax: world.yMax
        )
    }

    private func buildSceneGraph() {
        addAtmosphericBackground()
        addCourtFloor()
        addHoopAndBackboard()
        addPlayerSilhouette()
        addBall()
        startIdleDribbleIfNeeded()
    }

    private func addAtmosphericBackground() {
        let layer = SKNode()
        layer.zPosition = -10

        // Fake a vertical gradient with stacked thin rectangles — SKShapeNode has no CGGradient.
        let stripeCount = 24
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
        let reflectionHeight: CGFloat = 60
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
        let leftPoint = transform.scenePoint(world: CGPoint(x: CGFloat(projectileParams.world.xMin), y: CGFloat(projectileParams.world.floorY)))
        let rightPoint = transform.scenePoint(world: CGPoint(x: CGFloat(projectileParams.world.xMax), y: CGFloat(projectileParams.world.floorY)))

        let floor = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: leftPoint)
        path.addLine(to: rightPoint)
        floor.path = path
        floor.strokeColor = UIColor(white: 1.0, alpha: 0.3)
        floor.lineWidth = 1
        addChild(floor)

        let release = projectileParams.releasePosition
        let releaseX = transform.scenePoint(world: CGPoint(x: CGFloat(release[0]), y: 0)).x
        let accent = SKShapeNode()
        let accentPath = CGMutablePath()
        accentPath.move(to: CGPoint(x: releaseX - 40, y: leftPoint.y))
        accentPath.addLine(to: CGPoint(x: releaseX + 40, y: leftPoint.y))
        accent.path = accentPath
        accent.strokeColor = teamAccent.withAlphaComponent(0.55)
        accent.lineWidth = 2
        addChild(accent)
    }

    private func addHoopAndBackboard() {
        let hoop = projectileParams.target

        if let backboard = hoop.backboard {
            let bbCenter = transform.scenePoint(world: CGPoint(x: CGFloat(backboard.position[0]), y: CGFloat(backboard.position[1])))
            // JSON.height is physical vertical extent; we use it as the visual board width.
            let visualBoardWidth = transform.sceneDistance(world: backboard.height)
            let visualBoardHeight = transform.sceneDistance(world: 0.60)

            let outerNode = SKShapeNode(rectOf: CGSize(width: visualBoardWidth, height: visualBoardHeight))
            outerNode.position = bbCenter
            outerNode.fillColor = UIColor(white: 1.0, alpha: 0.18)
            outerNode.strokeColor = UIColor(white: 1.0, alpha: 0.85)
            outerNode.lineWidth = 2
            addChild(outerNode)

            let innerW = visualBoardWidth * 0.40
            let innerH = visualBoardHeight * 0.55
            let inner = SKShapeNode(rectOf: CGSize(width: innerW, height: innerH))
            inner.position = CGPoint(x: bbCenter.x, y: bbCenter.y - visualBoardHeight * 0.10)
            inner.fillColor = .clear
            inner.strokeColor = UIColor(white: 1.0, alpha: 0.85)
            inner.lineWidth = 1.5
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
        rimEllipse.lineWidth = 3
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
        net.lineWidth = 1.5
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

    /// Idempotent — auto-pauses during ACTION via pauseIdleDribble().
    private func startIdleDribbleIfNeeded() {
        guard !isIdleDribbling,
              let arm = dribbleArmNode,
              let dribbleBall = dribbleBallShadowNode else { return }

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

        isIdleDribbling = true
    }

    private func pauseIdleDribble() {
        dribbleArmNode?.removeAction(forKey: "dribbleArm")
        dribbleBallShadowNode?.removeAction(forKey: "dribbleBall")
        dribbleBallShadowNode?.isHidden = true
        isIdleDribbling = false
    }

    private func resumeIdleDribble() {
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
        seam.lineWidth = 1
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

    func startSimulation(answer: ProjectileAnswer) {
        resetForNewShot()
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
        audio?.stopLoop(.dribbleLoop)
        audio?.play(.shoot)
        ballNode?.run(
            SKAction.repeatForever(SKAction.rotate(byAngle: 2 * .pi, duration: 0.4)),
            withKey: "ballSpin"
        )
        flashSceneForShoot()
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
            failed.lineWidth = 1.5
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
            let dashedPath = path.copy(dashingWithPhase: 0, lengths: [4, 4])
            let ghost = SKShapeNode()
            ghost.path = dashedPath
            ghost.strokeColor = UIColor(white: 1.0, alpha: 0.5)
            ghost.lineWidth = 1
            ghost.name = "ghostArc"
            ghost.zPosition = -1
            addChild(ghost)
        }

        if let lastPos = snapshotHistory.last?.ballPosition {
            let markerPos = transform.scenePoint(world: lastPos)
            let marker = SKLabelNode(fontNamed: "Menlo-Regular")
            marker.text = "✕"
            marker.fontSize = 18
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
        while accumulator >= dt {
            state = module.step(state: state, dt: dt)
            accumulator -= dt
            let snap = module.snapshot(state: state)
            snapshotHistory.append(snap)
        }
        currentState = state

        let latest = snapshotHistory.last!
        ballNode?.position = transform.scenePoint(world: latest.ballPosition)

        renderTrajectoryTrail()

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
        line.lineWidth = 1
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
        line.lineWidth = 1
        addChild(line)
        angleIndicatorNode = line

        let label = SKLabelNode(fontNamed: "Menlo-Regular")
        label.text = "\(Int(degrees.rounded()))°"
        label.fontSize = 11
        label.fontColor = UIColor(white: 1.0, alpha: 0.7)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: endpoint.x + 8, y: endpoint.y)
        label.name = "angleLabel"
        addChild(label)
    }
}
