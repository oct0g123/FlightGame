/// Advances a `World` one fixed tick at a time.
public enum Simulation {
    /// Seconds per tick.
    public static let dt: Float = 1 / Float(FlightCore.tickRate)
    /// Aircraft whose heights differ by less than this many levels can collide.
    public static let verticalSeparation: Float = 0.6
    /// The last stretch of a committed path, where the aircraft glides from level 1 to the ground.
    public static let finalGlide: Float = 6
    /// A conflict warning starts at this multiple of the two collision radii.
    public static let warningFactor: Float = 2

    /// Advances the world by one tick. Deterministic: the same world and
    /// commands always produce the same result and events.
    @discardableResult
    public static func step(_ world: inout World, commands: [Command]) -> [GameEvent] {
        guard world.phase == .playing else { return [] }
        var events: [GameEvent] = []
        for command in commands {
            world.apply(command, events: &events)
        }
        world.updateSpawner(events: &events)
        world.moveAircraft(events: &events)
        world.checkSeparation(events: &events)
        world.tick += 1
        return events
    }

    /// Distance at which two aircraft start warning about each other.
    public static func warningDistance(_ a: AircraftKind, _ b: AircraftKind) -> Float {
        (a.spec.radius + b.spec.radius) * warningFactor
    }
}
