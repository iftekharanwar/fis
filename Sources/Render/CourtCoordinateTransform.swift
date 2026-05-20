import CoreGraphics

/// Maps simulation world-coordinates (meters, origin at player feet, +y up)
/// into SKScene point coordinates (origin at scene's bottom-left, +y up).
///
/// All scenario JSON values (`releasePosition`, `target.center`, `world.xMin`,
/// etc.) are in meters. The simulation runs in meters. The renderer needs
/// points. This transform is the single place that conversion happens.
///
/// **Anchor strategy**: scale so the world's `xMin → xMax` range fills the
/// scene horizontally minus a small margin. y is scaled by the same factor
/// to keep aspect ratio. The bottom safe-area corresponds to `world.floorY`.
struct CourtCoordinateTransform {
    /// Scene size in points (passed in from SpriteView container).
    let sceneSize: CGSize

    /// World bounds from the scenario's `simulation.params.world`.
    let worldXMin: Double
    let worldXMax: Double
    let worldFloorY: Double
    let worldYMax: Double

    /// Horizontal scene padding so the court doesn't touch the edges.
    let horizontalMargin: CGFloat = 12

    /// Vertical scene padding. Reduced from 32→8pt so the player+hoop fill
    /// more of the court area vertically without needing a `visualZoom`
    /// hack (which pushed positions off-screen). The smaller margin means
    /// the limiting dimension is now closer to the actual scene size, so
    /// the natural `min(xScale, yScale)` gives a larger visual scale
    /// without breaking position math.
    let verticalMargin: CGFloat = 8

    // MARK: - Derived

    private var scaleFactor: CGFloat {
        let usableWidth = sceneSize.width - 2 * horizontalMargin
        let usableHeight = sceneSize.height - 2 * verticalMargin
        let worldWidth = CGFloat(worldXMax - worldXMin)
        let worldHeight = CGFloat(worldYMax - worldFloorY)
        // Pick the smaller scale so neither dimension overflows. With a
        // tighter visual yMax (set in PlaySceneNode.rebuildTransform) and
        // small margins, the resulting scale renders the player+hoop large
        // enough to feel like a real court.
        let xScale = usableWidth / worldWidth
        let yScale = usableHeight / worldHeight
        return min(xScale, yScale)
    }

    // MARK: - Conversion

    /// Convert a world-coordinate point (meters) to scene-coordinate point.
    func scenePoint(world: CGPoint) -> CGPoint {
        let scale = scaleFactor
        let x = horizontalMargin + (world.x - CGFloat(worldXMin)) * scale
        let y = verticalMargin + (world.y - CGFloat(worldFloorY)) * scale
        return CGPoint(x: x, y: y)
    }

    /// Convert a world-coordinate distance (meters) to scene-coordinate
    /// distance (points). Used for radii.
    func sceneDistance(world: Double) -> CGFloat {
        CGFloat(world) * scaleFactor
    }
}
