/// Identifies an aircraft for its whole flight. Never reused within a game.
public struct AircraftID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) { self.rawValue = rawValue }

    public static func < (lhs: AircraftID, rhs: AircraftID) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { "#\(rawValue)" }
}

public enum FlightState: Equatable, Sendable {
    case flying
    /// On the runway or pad. Can't collide; removed when the roll-out ends.
    case landing(runway: RunwayID, elapsed: Float)
}

public struct Aircraft: Identifiable, Sendable {
    public let id: AircraftID
    public let kind: AircraftKind
    public internal(set) var position: Vec2
    public internal(set) var heading: Float
    /// Radians per second this tick. Positive is counter-clockwise. Drives the visual bank.
    public internal(set) var turnRate: Float = 0
    /// Height in level units: 0 is the ground, 1–3 are flight levels.
    public internal(set) var altitude: Float
    /// The level the aircraft is climbing or descending to.
    public internal(set) var targetLevel: Int
    /// Current speed, in units per second.
    public internal(set) var speed: Float
    public internal(set) var state: FlightState = .flying
    public internal(set) var path: FlightPath?
    /// False until the aircraft first crosses into the playfield.
    public internal(set) var hasEnteredField = false

    // Values at the previous tick, for smooth interpolation between ticks.
    public internal(set) var previousPosition: Vec2
    public internal(set) var previousHeading: Float
    public internal(set) var previousAltitude: Float

    init(
        id: AircraftID, kind: AircraftKind, position: Vec2, heading: Float, level: Int, speed: Float
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.heading = heading
        self.altitude = Float(level)
        self.targetLevel = level
        self.speed = speed
        previousPosition = position
        previousHeading = heading
        previousAltitude = altitude
    }

    public var spec: AircraftSpec { kind.spec }
    public var isFlying: Bool { state == .flying }

    /// Position `alpha` of the way from the previous tick to this one.
    public func position(interpolatedBy alpha: Float) -> Vec2 {
        previousPosition.lerp(to: position, alpha)
    }

    /// Heading `alpha` of the way from the previous tick to this one, turning the short way.
    public func heading(interpolatedBy alpha: Float) -> Float {
        Angles.wrap(previousHeading + Angles.delta(from: previousHeading, to: heading) * alpha)
    }

    /// Altitude `alpha` of the way from the previous tick to this one.
    public func altitude(interpolatedBy alpha: Float) -> Float {
        previousAltitude + (altitude - previousAltitude) * alpha
    }

    mutating func rememberPreviousTick() {
        previousPosition = position
        previousHeading = heading
        previousAltitude = altitude
    }
}
