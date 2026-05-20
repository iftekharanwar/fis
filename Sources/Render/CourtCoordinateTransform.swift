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
        let usableWidth = sceneSize.width - 2 * horizontalMargin
        let usableHeight = sceneSize.height - uiReserve.top - uiReserve.bottom - 2 * verticalMargin
        let worldWidth = CGFloat(worldXMax - worldXMin)
        let worldHeight = CGFloat(worldYMax - worldFloorY)
        let xScale = usableWidth / worldWidth
        let yScale = max(usableHeight, 1) / worldHeight
        return min(xScale, yScale)
    }

    /// Floor anchors at `uiReserve.bottom + verticalMargin` so the court sits
    /// just above the bottom UI band.
    func scenePoint(world: CGPoint) -> CGPoint {
        let scale = scaleFactor
        let x = horizontalMargin + (world.x - CGFloat(worldXMin)) * scale
        let y = uiReserve.bottom + verticalMargin + (world.y - CGFloat(worldFloorY)) * scale
        return CGPoint(x: x, y: y)
    }

    func sceneDistance(world: Double) -> CGFloat {
        CGFloat(world) * scaleFactor
    }
}
