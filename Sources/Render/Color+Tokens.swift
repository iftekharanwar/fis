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

    /// `#6B6B6B` — muted labels, captions, mid-grey. **One value only**;
    /// no second mid-grey allowed (per audit fix on 2026-05-19).
    static let arclabMidGrey = Color(hex: 0x6B6B6B)

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
