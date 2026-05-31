import CoreGraphics

/// Maps world-coordinates (meters, +y up) to scene-coordinate points (+y up).
struct CourtCoordinateTransform {
    let sceneSize: CGSize

    /// UI bands that occlude the scene. World framing happens inside the
    /// unoccluded vertical band (sceneHeight − top − bottom).
    let uiReserve: SceneInsets

    let worldXMin: Double
    let worldXMax: Double
    let worldFloorY: Double
    let worldYMax: Double

    let horizontalMargin: CGFloat = 12
    let verticalMargin: CGFloat = 8

    init(
        sceneSize: CGSize,
        worldXMin: Double,
        worldXMax: Double,
        worldFloorY: Double,
        worldYMax: Double,
        uiReserve: SceneInsets = .zero
    ) {
        self.sceneSize = sceneSize
        self.worldXMin = worldXMin
        self.worldXMax = worldXMax
        self.worldFloorY = worldFloorY
        self.worldYMax = worldYMax
        self.uiReserve = uiReserve
    }

    private var scaleFactor: CGFloat {
        // `right`/`left` reserve a side band (iPad landscape dock); the world is
        // framed into the remaining left-anchored region. Both default to 0, so
        // the portrait/bottom-dock geometry is unchanged.
        let usableWidth = sceneSize.width - 2 * horizontalMargin - uiReserve.left - uiReserve.right
        let usableHeight = sceneSize.height - uiReserve.top - uiReserve.bottom - 2 * verticalMargin
        let worldWidth = CGFloat(worldXMax - worldXMin)
        let worldHeight = CGFloat(worldYMax - worldFloorY)
        let xScale = max(usableWidth, 1) / worldWidth
        let yScale = max(usableHeight, 1) / worldHeight
        return min(xScale, yScale)
    }

    /// Floor anchors at `uiReserve.bottom + verticalMargin` so the court sits
    /// just above the bottom UI band; the left origin shifts past any left
    /// reserve so a right-side dock leaves the court in the left band.
    func scenePoint(world: CGPoint) -> CGPoint {
        let scale = scaleFactor
        let x = horizontalMargin + uiReserve.left + (world.x - CGFloat(worldXMin)) * scale
        let y = uiReserve.bottom + verticalMargin + (world.y - CGFloat(worldFloorY)) * scale
        return CGPoint(x: x, y: y)
    }

    func sceneDistance(world: Double) -> CGFloat {
        CGFloat(world) * scaleFactor
    }
}
