import Foundation
import Observation

/// SPOTTER overlay state (expression buffer + last result) shared across dismiss/re-present.
@Observable
@MainActor
final class SpotterService {

    /// Cleared on `⏎` insert or explicit `clear()`; preserved across sheet dismiss.
    var expression: String = ""

    /// Updated on `=` press; PLAY's input field observes via `.onChange` to avoid the
    /// iOS focus race when `⏎` dismisses the sheet and inserts in the same runloop tick.
    var lastResult: Double?

    func clear() {
        expression = ""
        lastResult = nil
    }
}
