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

    // MARK: - Bold Text (same OR-with-system contract as High Legibility)

    func testBoldTextDefaultsOff() {
        let settings = AccessibilitySettings(defaults: defaults, systemBoldText: false)
        XCTAssertFalse(settings.boldTextEnabled)
        XCTAssertFalse(settings.boldTextActive)
    }

    func testBoldTextTogglePersistsAcrossInstances() {
        let first = AccessibilitySettings(defaults: defaults, systemBoldText: false)
        first.boldTextEnabled = true

        let second = AccessibilitySettings(defaults: defaults, systemBoldText: false)
        XCTAssertTrue(second.boldTextEnabled)
        XCTAssertTrue(second.boldTextActive)
    }

    func testSystemBoldTextActivatesWithoutToggle() {
        let settings = AccessibilitySettings(defaults: defaults, systemBoldText: true)
        XCTAssertFalse(settings.boldTextEnabled, "system Bold Text must not flip the persisted user override")
        XCTAssertTrue(settings.boldTextActive)
    }

    func testSystemBoldTextChangeIsLive() {
        let settings = AccessibilitySettings(defaults: defaults, systemBoldText: false)
        XCTAssertFalse(settings.boldTextActive)
        settings.systemBoldText = true
        XCTAssertTrue(settings.boldTextActive)
    }

    // MARK: - Reduce Motion (same OR-with-system contract as High Legibility)

    func testReduceMotionDefaultsOffAndPersists() {
        let first = AccessibilitySettings(defaults: defaults, systemReduceMotion: false)
        XCTAssertFalse(first.reduceMotionActive)
        first.reduceMotionEnabled = true

        let second = AccessibilitySettings(defaults: defaults, systemReduceMotion: false)
        XCTAssertTrue(second.reduceMotionEnabled)
        XCTAssertTrue(second.reduceMotionActive)
    }

    func testSystemReduceMotionActivatesWithoutToggle() {
        let settings = AccessibilitySettings(defaults: defaults, systemReduceMotion: true)
        XCTAssertFalse(settings.reduceMotionEnabled, "system setting must not flip the persisted override")
        XCTAssertTrue(settings.reduceMotionActive)
    }

    func testSystemReduceMotionChangeIsLive() {
        let settings = AccessibilitySettings(defaults: defaults, systemReduceMotion: false)
        XCTAssertFalse(settings.reduceMotionActive)
        settings.systemReduceMotion = true
        XCTAssertTrue(settings.reduceMotionActive)
    }

    // MARK: - Haptics (default ON, persisted)

    func testHapticsDefaultsOnAndPersists() {
        let first = AccessibilitySettings(defaults: defaults)
        XCTAssertTrue(first.hapticsEnabled, "haptics default ON")
        first.hapticsEnabled = false

        let second = AccessibilitySettings(defaults: defaults)
        XCTAssertFalse(second.hapticsEnabled)
    }
}
