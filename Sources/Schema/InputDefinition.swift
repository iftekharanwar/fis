import Foundation

struct InputDefinition: Codable, Sendable, Equatable {
    let mode: InputMode
    let fields: [Field]
    let submitLabel: String

    enum InputMode: String, Codable, Sendable {
        case numpadSingle = "NUMPAD_SINGLE"
        case numpadDual   = "NUMPAD_DUAL"
        case dial         = "DIAL"
        case slider       = "SLIDER"
        case dragTarget   = "DRAG_TARGET"
        case pathTap      = "PATH_TAP"
        case connectNodes = "CONNECT_NODES"
    }

    struct Field: Codable, Sendable, Equatable {
        let name: String              // key for matching answer back to input ("theta", "v")
        let label: String
        let unit: String
        let min: Double
        let max: Double
        let decimals: Int
        let placeholder: String?
    }
}
