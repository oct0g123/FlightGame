/// The kinds of aircraft, each landing on its own class of runway.
public enum AircraftKind: String, CaseIterable, Codable, Sendable {
    /// Light propeller plane. Short runway.
    case prop
    /// Jet. Long runway.
    case jet
    /// Helicopter. Helipad, from any direction.
    case heli

    public var spec: AircraftSpec {
        switch self {
        case .prop:
            AircraftSpec(
                speed: 7, radius: 2.5, maxTurnRate: Angles.radians(fromDegrees: 120),
                climbRate: 1 / 3, ceiling: 3)
        case .jet:
            AircraftSpec(
                speed: 10, radius: 3, maxTurnRate: Angles.radians(fromDegrees: 90),
                climbRate: 0.4, ceiling: 3)
        case .heli:
            AircraftSpec(
                speed: 5, radius: 2.5, maxTurnRate: Angles.radians(fromDegrees: 180),
                climbRate: 0.5, ceiling: 2)
        }
    }
}

/// How an aircraft kind flies. Distances are in field units.
public struct AircraftSpec: Sendable {
    /// Cruise speed, in units per second.
    public let speed: Float
    /// Collision radius.
    public let radius: Float
    /// Fastest turn, in radians per second.
    public let maxTurnRate: Float
    /// Climb and descent rate, in levels per second.
    public let climbRate: Float
    /// Highest flight level this kind can use.
    public let ceiling: Int
}
