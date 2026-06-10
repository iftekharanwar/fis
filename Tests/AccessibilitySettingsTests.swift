import XCTest
@testable import PhysicsGame

/// AccessibilitySettings — the store behind the High Legibility palette.
/// Color resolution itself is visual (verified manually per the halation
/// research: no automated check catches glow); these tests pin the state
/// logic the tokens key off.
@MainActor
final class AccessibilitySettingsTests: XCTestCase {

    private static let suiteName = "AccessibilitySettingsTests"
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: Self.suiteName)
    }

    func testDefaultIsStandardPalette() {
        let settings = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: false)
        XCTAssertFalse(settings.highLegibilityEnabled)
        XCTAssertFalse(settings.highLegibilityActive)
    }

    func testTogglePersistsAcrossInstances() {
        let first = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: false)
        first.highLegibilityEnabled = true

        let second = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: false)
        XCTAssertTrue(second.highLegibilityEnabled)
        XCTAssertTrue(second.highLegibilityActive)
    }

    func testSystemIncreaseContrastActivatesPaletteWithoutToggle() {
        let settings = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: true)
        XCTAssertFalse(settings.highLegibilityEnabled, "system contrast must not flip the persisted user override")
        XCTAssertTrue(settings.highLegibilityActive)
    }

    func testSystemContrastChangeIsLive() {
        let settings = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: false)
        XCTAssertFalse(settings.highLegibilityActive)
        settings.systemIncreaseContrast = true
        XCTAssertTrue(settings.highLegibilityActive)
    }

    func testTurningToggleOffDeactivatesWhenSystemIsOff() {
        let settings = AccessibilitySettings(defaults: defaults, systemIncreaseContrast: false)
        settings.highLegibilityEnabled = true
        XCTAssertTrue(settings.highLegibilityActive)
        settings.highLegibilityEnabled = false
        XCTAssertFalse(settings.highLegibilityActive)
    }
}
