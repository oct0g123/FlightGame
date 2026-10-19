import FlightCore
import SwiftUI

/// Colours for the flat playtest view. Every runway class also has a glyph,
/// so nothing depends on colour alone.
enum Palette {
    static let sky = Color(red: 0.72, green: 0.84, blue: 0.93)
    static let grass = Color(red: 0.62, green: 0.77, blue: 0.53)
    static let tarmac = Color(red: 0.34, green: 0.36, blue: 0.39)
    static let terrain = Color(red: 0.55, green: 0.43, blue: 0.32)
    static let warning = Color(red: 0.92, green: 0.22, blue: 0.2)
    static let caution = Color(red: 0.98, green: 0.62, blue: 0.1)
}

extension AircraftKind {
    var color: Color {
        switch self {
        case .prop: Color(red: 0.96, green: 0.76, blue: 0.16)
        case .jet: Color(red: 0.89, green: 0.3, blue: 0.27)
        case .heli: Color(red: 0.24, green: 0.66, blue: 0.38)
        }
    }

    var glyph: String {
        switch self {
        case .prop: "●"
        case .jet: "▲"
        case .heli: "■"
        }
    }
}

extension Runway {
    /// The class this runway serves, for its colour and glyph.
    var kind: AircraftKind { AircraftKind.allCases.first { accepts($0) } ?? .prop }
}
