import SwiftUI

/// Reserved UI bands that occlude the full-bleed SpriteKit scene. Pushed into
/// the scene so the world transform frames action inside the unoccluded area.
struct SceneInsets: Equatable, Sendable {
    var top: CGFloat
    var bottom: CGFloat
    var safeTop: CGFloat
    var safeBottom: CGFloat

    static let zero = SceneInsets(top: 0, bottom: 0, safeTop: 0, safeBottom: 0)
}

/// Per-device layout numbers for PLAY. Single source of truth — every PLAY
/// subview reads from the same instance.
struct PlayLayoutMetrics: Equatable, Sendable {
    /// Total reserved at the top (HUD + variable strip + safe-area top).
    let topReserve: CGFloat
    /// Reserved at the bottom during .idle (input dock + safe-area bottom).
    let bottomReserveIdle: CGFloat
    /// Reserved at the bottom during .action (zero — scene takes full screen).
    let bottomReserveAction: CGFloat
    /// Reserved at the bottom during .outcome (outcome composition height).
    let bottomReserveOutcome: CGFloat

    /// Numpad sheet height when revealed.
    let numpadSheetHeight: CGFloat
    /// Each numpad button row height. 4 rows.
    let numpadRowHeight: CGFloat

    /// Each input row (ANGLE / VELOCITY readout) height.
    let inputRowHeight: CGFloat
    /// SHOOT verb hit-area height.
    let shootHeight: CGFloat

    /// Whether to compress the variable strip on small phones.
    let variableStripCondensed: Bool

    /// Reserves match actual SwiftUI overlay heights. Bump these when the
    /// typographic dock redesign (task #94) replaces the legacy input view.
    static func compute(for size: CGSize, safeArea: EdgeInsets) -> PlayLayoutMetrics {
        let h = size.height
        let safeTop = safeArea.top
        let safeBottom = safeArea.bottom

        if h < 700 {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 280,
                numpadRowHeight: 56,
                inputRowHeight: 44,
                shootHeight: 56,
                variableStripCondensed: true
            )
        } else if h < 920 {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 320,
                numpadRowHeight: 64,
                inputRowHeight: 52,
                shootHeight: 64,
                variableStripCondensed: false
            )
        } else {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 360,
                numpadRowHeight: 72,
                inputRowHeight: 56,
                shootHeight: 72,
                variableStripCondensed: false
            )
        }
    }
}
