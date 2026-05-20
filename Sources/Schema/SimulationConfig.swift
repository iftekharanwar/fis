import Foundation

/// Discriminated union of per-domain simulation params keyed on the `module` JSON field.
enum SimulationConfig: Codable, Sendable, Equatable {
    case projectile2D(moduleVersion: SemVer, params: Projectile2DParams)

    /// Must match a registered SimulationModule's `moduleId`.
    var moduleId: String {
        switch self {
        case .projectile2D: return "PROJECTILE_2D"
        }
    }

    /// Bumped independently of the schema envelope.
    var moduleVersion: SemVer {
        switch self {
        case .projectile2D(let v, _): return v
        }
    }

    private enum CodingKeys: String, CodingKey {
        case module
        case moduleVersion
        case params
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let moduleId = try container.decode(String.self, forKey: .module)
        let version = try container.decode(SemVer.self, forKey: .moduleVersion)

        switch moduleId {
        case "PROJECTILE_2D":
            let params = try container.decode(Projectile2DParams.self, forKey: .params)
            self = .projectile2D(moduleVersion: version, params: params)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .module,
                in: container,
                debugDescription: "Unknown simulation module '\(moduleId)'. Registered modules: PROJECTILE_2D."
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(moduleId, forKey: .module)
        try container.encode(moduleVersion, forKey: .moduleVersion)
        switch self {
        case .projectile2D(_, let params):
            try container.encode(params, forKey: .params)
        }
    }
}

/// MAJOR.MINOR.PATCH — no pre-release or build tags.
struct SemVer: Codable, Sendable, Equatable, Hashable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let parts = raw.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected MAJOR.MINOR.PATCH semver, got '\(raw)'."
            )
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

/// Per-scenario parameters for the `PROJECTILE_2D` module.
struct Projectile2DParams: Codable, Sendable, Equatable {
    let gravity: Double
    let airResistance: Double
    let releasePosition: [Double]   // [x, y]
    let ball: BallParams
    let target: TargetParams
    let world: WorldBounds
    let integrator: IntegratorKind
    let fixedDtSeconds: Double

    enum IntegratorKind: String, Codable, Sendable {
        case semiImplicitEuler = "SEMI_IMPLICIT_EULER"
        case verlet = "VERLET"
        case rk4 = "RK4"
    }

    struct BallParams: Codable, Sendable, Equatable {
        let radius: Double
        let mass: Double
    }

    struct TargetParams: Codable, Sendable, Equatable {
        let kind: String   // "HOOP" for basketball
        let center: [Double]
        let innerRadius: Double
        let rimThickness: Double
        let backboard: BackboardParams?
    }

    struct BackboardParams: Codable, Sendable, Equatable {
        let position: [Double]
        let width: Double
        let height: Double
    }

    struct WorldBounds: Codable, Sendable, Equatable {
        let floorY: Double
        let xMin: Double
        let xMax: Double
        let yMax: Double
    }
}
