@testable import FlightCore

/// A small three-level map and quiet profiles for focused tests.
enum Fixtures {
    static let level = Level(
        id: "fixture", name: "Fixture", size: Vec2(160, 100), flightLevels: 3,
        runways: [
            Runway(
                id: "long", accepts: [.jet], threshold: Vec2(40, 30), heading: 0, length: 50,
                captureRadius: 6),
            Runway(
                id: "short", accepts: [.prop], threshold: Vec2(60, 70), heading: 0, length: 28,
                captureRadius: 5),
            Runway(
                id: "pad", accepts: [.heli], threshold: Vec2(130, 70), captureRadius: 4,
                anyHeading: true),
        ],
        noFlyZones: [NoFlyZone(id: "peak", center: Vec2(110, 30), radius: 8, ceiling: 2)]
    )

    /// Nothing ever arrives, so tests control every aircraft.
    static let quiet = DifficultyProfile(
        id: "quiet",
        spawnInterval: Decay(start: 5, end: 5, halfLife: 1),
        maxAirborne: Curve([(0, 0)]),
        mix: [MixStep(time: 0, weights: [.prop: 1])]
    )

    /// Like `quiet`, but three crashes are allowed.
    static let quietRelaxed = DifficultyProfile(
        id: "quiet-relaxed",
        spawnInterval: Decay(start: 5, end: 5, halfLife: 1),
        maxAirborne: Curve([(0, 0)]),
        mix: [MixStep(time: 0, weights: [.prop: 1])],
        strikes: 3
    )

    static func world(_ profile: DifficultyProfile = quiet, seed: UInt64 = 1) -> World {
        World(level: level, profile: profile, seed: seed)
    }

    /// A straight line of raw input points from `start` to `end`, every `step` units.
    static func line(from start: Vec2, to end: Vec2, step: Float = 2) -> [Vec2] {
        let count = max(Int((start.distance(to: end) / step).rounded(.up)), 1)
        return (1...count).map { start.lerp(to: end, Float($0) / Float(count)) }
    }
}

extension World {
    /// Puts an aircraft directly into the world, already inside the field.
    @discardableResult
    mutating func place(_ kind: AircraftKind, at position: Vec2, heading: Float = 0, level: Int = 1)
        -> AircraftID
    {
        let id = AircraftID(nextID)
        nextID += 1
        var plane = Aircraft(
            id: id, kind: kind, position: position, heading: heading, level: level,
            speed: kind.spec.speed)
        plane.hasEnteredField = level > 0
        aircraft.append(plane)
        return id
    }

    /// Runs whole ticks for `seconds`, sending `commands` on the first one.
    @discardableResult
    mutating func run(seconds: Float, commands: [Command] = []) -> [GameEvent] {
        var events = Simulation.step(&self, commands: commands)
        let ticks = Int((seconds / Simulation.dt).rounded())
        for _ in 1..<max(ticks, 1) {
            events += Simulation.step(&self, commands: [])
        }
        return events
    }

    /// Draws a complete path for an aircraft in one tick.
    @discardableResult
    mutating func draw(_ id: AircraftID, through points: [Vec2], level: Int? = nil) -> [GameEvent] {
        guard let first = points.first else { return [] }
        return Simulation.step(
            &self,
            commands: [
                .startPath(id, at: first),
                .extendPath(id, points: Array(points.dropFirst()), level: level),
                .finishPath(id),
            ])
    }
}
