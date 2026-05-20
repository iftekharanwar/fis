import Foundation

/// Typed wrapper around a scenario's string identifier. `CodingKeyRepresentable`
/// conformance is required so `[ScenarioID: ScenarioRecord]` encodes as a JSON
/// object instead of an array; without it persisted profiles fail to decode.
struct ScenarioID: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible, CodingKeyRepresentable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var description: String { rawValue }

    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    var codingKey: CodingKey {
        Key(stringValue: rawValue)
    }

    init?<T: CodingKey>(codingKey: T) {
        self.rawValue = codingKey.stringValue
    }
}
