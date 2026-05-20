import SwiftUI
import Observation
import UIKit

/// Refcounted pause/resume gate for ambient motion. Honors system Reduce Motion.
@Observable
@MainActor
final class MotionController {

    /// Refcount so nested pause/resume pairs from concurrent screens don't fight.
    private var resumeCount: Int = 0

    var isMotionAllowed: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    var isRunning: Bool {
        isMotionAllowed && resumeCount > 0
    }

    func resume() {
        resumeCount += 1
    }

    func pause() {
        resumeCount = max(0, resumeCount - 1)
    }
}
