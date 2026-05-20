import Foundation
import Observation

/// Premium subscription status. MVP hardcodes `.premium`; v1.1 wires StoreKit.
@Observable
@MainActor
final class SubscriptionService {

    enum Status: Sendable, Equatable {
        case premium
        case free
        case unknown
    }

    var status: Status = .premium

    var isPremium: Bool { status == .premium }
}
