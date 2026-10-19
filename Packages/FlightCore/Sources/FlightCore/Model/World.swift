/// The whole state of one game. A value type: `Simulation.step` advances it.
public struct World: Sendable {
    public let level: Level
    public let profile: DifficultyProfile
    public let seed: UInt64

    public internal(set) var tick: UInt64 = 0
    public internal(set) var aircraft: [Aircraft] = []
    /// Arrivals that have been announced but haven't appeared yet.
    public internal(set) var pendingArrivals: [PendingArrival] = []
    /// Pairs of aircraft currently too close for comfort.
    public internal(set) var conflicts: Set<AircraftPair> = []
    /// Aircraft landed so far: the score. Counted at touchdown.
    public internal(set) var landed = 0
    public internal(set) var strikesLeft: Int
    public internal(set) var phase: Phase = .playing

    var spawner: SpawnerState
    var random: RandomStreams
    var nextID: UInt32 = 1

    public init(level: Level, profile: DifficultyProfile, seed: UInt64) {
        self.level = level
        self.profile = profile
        self.seed = seed
        strikesLeft = max(profile.strikes, 1)
        spawner = SpawnerState(nextArrival: profile.warningLead + 1)
        random = RandomStreams(seed: seed)
    }

    /// Seconds since the game started.
    public var time: Float { Float(tick) * Simulation.dt }

    public var isOver: Bool { phase != .playing }

    public func aircraft(_ id: AircraftID) -> Aircraft? { aircraft.first { $0.id == id } }

    func index(of id: AircraftID) -> Int? { aircraft.firstIndex { $0.id == id } }
}

public enum Phase: Equatable, Sendable {
    case playing
    case over(Crash)
}

public enum Crash: Equatable, Sendable {
    case midair(AircraftPair, at: Vec2)
    case terrain(AircraftID, at: Vec2)

    public var aircraft: [AircraftID] {
        switch self {
        case .midair(let pair, _): [pair.first, pair.second]
        case .terrain(let id, _): [id]
        }
    }

    public var location: Vec2 {
        switch self {
        case .midair(_, let at), .terrain(_, let at): at
        }
    }
}

/// Two aircraft, in a fixed order so a pair always compares equal.
public struct AircraftPair: Hashable, Comparable, Sendable {
    public let first: AircraftID
    public let second: AircraftID

    public init(_ a: AircraftID, _ b: AircraftID) {
        first = min(a, b)
        second = max(a, b)
    }

    public func contains(_ id: AircraftID) -> Bool { first == id || second == id }

    public static func < (lhs: AircraftPair, rhs: AircraftPair) -> Bool {
        (lhs.first, lhs.second) < (rhs.first, rhs.second)
    }
}

/// An announced arrival: where and when it will appear.
public struct PendingArrival: Equatable, Sendable {
    public let kind: AircraftKind
    public let level: Int
    public let edge: Edge
    /// Where it appears, just outside the field.
    public let entry: Vec2
    public let heading: Float
    public internal(set) var spawnTime: Float
}
