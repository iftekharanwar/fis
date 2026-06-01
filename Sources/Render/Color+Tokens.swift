import SwiftUI

/// The color tokens locked in `CONCEPT.md` and `SCREENS.md` Conventions.
/// Every screen references these — never hardcoded hex values, anywhere.
///
/// Crimson is **sacred to the MISS state.** Never on splash errors, never
/// on offline banners, never as "danger." Only on a missed shot. The semantic
/// weight of crimson is the most expensive asset in the design system.
extension Color {

    // MARK: - Base palette

    /// `#000000` — full-bleed background everywhere.
    static let arclabBlack = Color(red: 0, green: 0, blue: 0)

    /// `#FFFFFF` — primary type.
    static let arclabWhite = Color(red: 1, green: 1, blue: 1)

    /// `#8A8A8A` — muted labels, captions, mid-grey. **One value only**;
    /// no second mid-grey allowed (per audit fix on 2026-05-19). Raised from
    /// `#6B6B6B` on 2026-05-29: the old value was 3.9:1 on black, under the
    /// WCAG AA 4.5:1 floor for body text. `#8A8A8A` clears it (~6:1) while
    /// staying perceptibly muted next to `arclabWhite`.
    static let arclabMidGrey = Color(hex: 0x8A8A8A)

    /// `#3A3A3A` — 1pt rules and chip borders.
    static let arclabBorderGrey = Color(hex: 0x3A3A3A)

    /// `#FF3037` — **sacred to MISS state.** Do not use on any non-loss surface.
    static let arclabCrimson = Color(hex: 0xFF3037)

    // MARK: - MISS background tints

    /// `#0C0404` — default MISS background tint. Perceptible on OLED across
    /// True Tone, Night Shift, and Increase Contrast. (Originally `#060202`,
    /// bumped after audit found that delta was below JND.)
    static let arclabMissTint = Color(hex: 0x0C0404)

    /// `#180404` — deeper tint reserved for AIRBALL category.
    static let arclabMissTintAirball = Color(hex: 0x180404)

    // MARK: - Scene illustration sub-palette
    //
    // These tokens are *only* used inside scenario preview illustrations
    // (Home hero card, lesson diagrams, etc.). They never appear in UI chrome
    // — that stays on the base palette above. Keeps the main system tight
    // while letting illustrations have their own internal language.

    /// `#0E0E0E` — card surface background, one notch above pure black so
    /// cards lift visually from the page.
    static let arclabCardBlack = Color(hex: 0x0E0E0E)

    /// `#181818` — scene back-panel inside the card; separates the
    /// illustration zone from the text content zone.
    static let arclabSceneBg = Color(hex: 0x181818)

    /// `#B57B3F` — amber wood floor inside illustrations.
    static let arclabFloorWood = Color(hex: 0xB57B3F)

    /// `#F5F1E8` — painted floor lines + backboard surface.
    static let arclabFloorLine = Color(hex: 0xF5F1E8)
    static let arclabBackboard = Color(hex: 0xF5F1E8)

    /// `#E8782B` — illustration orange (rim, ball). Distinct from crimson;
    /// reads as "basketball" not "miss."
    static let arclabRimOrange = Color(hex: 0xE8782B)
    static let arclabBallOrange = Color(hex: 0xE8782B)

    /// `#8B3F10` — ball seam shadow.
    static let arclabBallShadow = Color(hex: 0x8B3F10)

    /// `#000000` — silhouette figure inside illustrations. Pure black
    /// against the lighter `arclabSceneBg` reads cleanly as a silhouette.
    static let arclabSilhouette = Color(hex: 0x000000)
}

// MARK: - Hex initializer

extension Color {
    /// Tiny hex initializer so the token file stays readable. Accepts 0xRRGGBB.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
