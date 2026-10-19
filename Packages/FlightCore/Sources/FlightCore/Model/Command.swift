/// Something the player (or the autopilot) asks for. Applied at the start of a tick.
public enum Command: Equatable, Codable, Sendable {
    /// Start a new path for this aircraft, replacing any old one.
    case startPath(AircraftID, at: Vec2)
    /// Add raw input points. `level` is the level picked by hand height on visionOS.
    case extendPath(AircraftID, points: [Vec2], level: Int?)
    /// The finger lifted.
    case finishPath(AircraftID)
    /// Climb or descend to a level (▲/▼, scroll, flick).
    case setLevel(AircraftID, Int)
}

public enum RejectReason: String, Codable, Sendable {
    /// The path ends at a runway this kind can't use.
    case wrongRunway
    /// The path is too short to descend to the ground in time.
    case tooHigh
}

/// Something that happened during a tick, for presentation, audio and haptics.
public enum GameEvent: Equatable, Sendable {
    case arrivalWarning(PendingArrival)
    case spawned(AircraftID)
    case pathCommitted(AircraftID, RunwayID)
    case pathRejected(AircraftID, at: Vec2, reason: RejectReason)
    case levelChanged(AircraftID, level: Int)
    case touchedDown(AircraftID, RunwayID)
    case landed(AircraftID)
    case conflictBegan(AircraftPair)
    case conflictEnded(AircraftPair)
    case crashed(Crash)
    case gameOver(Crash)
}
