import XCTest
import SwiftUI
@testable import PhysicsGame

/// Phase 1 adaptive-layout infra tests. Pin the two invariants the redesign
/// depends on: the compact path is byte-for-byte the legacy bottom-dock
/// geometry (so iPhone is unchanged), and regular landscape switches to the
/// right-side dock with the bottom band collapsed.
final class AdaptiveLayoutTests: XCTestCase {

    private let phoneSafeArea = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)

    // MARK: - LayoutContext.resolve

    func test_resolve_iPhonePortrait_isCompactPortrait() {
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: .compact,
            size: CGSize(width: 393, height: 852),
            safeArea: phoneSafeArea
        )
        XCTAssertEqual(ctx.form, .compact)
        XCTAssertEqual(ctx.orientation, .portrait)
        XCTAssertFalse(ctx.isRegular)
        XCTAssertFalse(ctx.isWide)
        XCTAssertEqual(ctx.typeScale, 1.0, "compact must not scale typography")
    }

    func test_resolve_iPadLandscape_isRegularWide() {
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: .regular,
            size: CGSize(width: 1366, height: 1024),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        )
        XCTAssertEqual(ctx.form, .regular)
        XCTAssertEqual(ctx.orientation, .landscape)
        XCTAssertTrue(ctx.isRegular)
        XCTAssertTrue(ctx.isWide)
        XCTAssertGreaterThan(ctx.typeScale, 1.0)
    }

    func test_resolve_nilSizeClass_treatedAsCompact() {
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: nil,
            size: CGSize(width: 400, height: 800),
            safeArea: .init()
        )
        XCTAssertEqual(ctx.form, .compact)
    }

    // MARK: - AdaptiveMetrics.compute

    func test_metrics_compactPortrait_keepsBottomDock() {
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: .compact,
            size: CGSize(width: 393, height: 852),
            safeArea: phoneSafeArea
        )
        let m = AdaptiveMetrics.compute(ctx: ctx, topReserve: 159, desiredBottomDockHeight: 364)
        XCTAssertFalse(m.usesSideDock)
        XCTAssertEqual(m.rightReserve, 0, "iPhone must reserve no side band")
        XCTAssertEqual(m.bottomReserve, 364, "bottom dock height passes through unchanged")
        XCTAssertEqual(m.topReserve, 159)
    }

    func test_metrics_iPadPortrait_keepsBottomDock() {
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: .regular,
            size: CGSize(width: 1024, height: 1366),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        )
        let m = AdaptiveMetrics.compute(ctx: ctx, topReserve: 124, desiredBottomDockHeight: 364)
        XCTAssertFalse(m.usesSideDock, "iPad portrait keeps the bottom-dock model")
        XCTAssertEqual(m.rightReserve, 0)
        XCTAssertEqual(m.bottomReserve, 364)
    }

    func test_metrics_iPadLandscape_usesSideDock() {
        let size = CGSize(width: 1366, height: 1024)
        let ctx = LayoutContext.resolve(
            horizontalSizeClass: .regular,
            size: size,
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        )
        let m = AdaptiveMetrics.compute(ctx: ctx, topReserve: 124, desiredBottomDockHeight: 480)
        XCTAssertTrue(m.usesSideDock)
        XCTAssertGreaterThan(m.rightReserve, 0)
        XCTAssertEqual(m.rightReserve, AdaptiveMetrics.sideDockWidth(for: size.width))
        XCTAssertEqual(m.bottomReserve, ctx.safeArea.bottom,
                       "landscape collapses the bottom band to just the safe area")
        XCTAssertEqual(m.dockHeight, size.height)
    }

    func test_sideDockWidth_isClamped() {
        XCTAssertEqual(AdaptiveMetrics.sideDockWidth(for: 800), 360, "floor at 360")
        XCTAssertEqual(AdaptiveMetrics.sideDockWidth(for: 5000), 480, "ceiling at 480")
        XCTAssertEqual(AdaptiveMetrics.sideDockWidth(for: 1100), 418, accuracy: 0.5,
                       "1100 * 0.38 within range")
    }

    // MARK: - SceneInsets back-compat

    func test_sceneInsets_defaultSideBandsAreZero() {
        let s = SceneInsets(top: 100, bottom: 330, safeTop: 59, safeBottom: 34)
        XCTAssertEqual(s.left, 0)
        XCTAssertEqual(s.right, 0)
        XCTAssertEqual(SceneInsets.zero.right, 0)
    }
}
