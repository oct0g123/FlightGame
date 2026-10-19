import Observation

/// Runs one game: steps the simulation at a fixed rate, queues commands, and
/// publishes what the UI needs.
///
/// Drive it from the render loop with `advance(by:)`. SwiftUI observes `hud`,
/// which changes a few times a second at most; renderers read `world` and
/// `alpha` every frame without triggering view updates.
@MainActor
@Observable
public final class GameSession {
    /// What the HUD shows. Only written when a value actually changes.
    public private(set) var hud: HUDState
    public var isPaused = false

    @ObservationIgnored public private(set) var world: World
    /// How far the clock is between the last tick and the next (0–1), for smooth drawing.
    @ObservationIgnored public private(set) var alpha: Float = 0
    /// Events from the most recent `advance(by:)`.
    @ObservationIgnored public private(set) var frameEvents: [GameEvent] = []
    /// Every command so far, for bug reports and tests.
    @ObservationIgnored public private(set) var replay: Replay

    @ObservationIgnored private var pending: [Command] = []
    @ObservationIgnored private var accumulator: Double = 0

    /// Longest stretch simulated in one call, so a hitch doesn't fast-forward the game.
    public static let maxStep: Double = 0.25

    public init(level: Level, profile: DifficultyProfile, seed: UInt64) {
        let world = World(level: level, profile: profile, seed: seed)
        self.world = world
        hud = HUDState(world)
        replay = Replay(levelID: level.id, profileID: profile.id, seed: seed)
    }

    /// Queues a command for the next tick.
    public func send(_ command: Command) {
        pending.append(command)
    }

    public func send(_ commands: [Command]) {
        pending += commands
    }

    /// Runs as many fixed ticks as `seconds` covers, carrying the remainder over.
    public func advance(by seconds: Double) {
        frameEvents.removeAll(keepingCapacity: true)
        guard !isPaused, !world.isOver else { return }
        accumulator += min(max(seconds, 0), Self.maxStep)
        let dt = 1 / Double(FlightCore.tickRate)
        // The tolerance stops rounding error from dropping a tick (2 × 1/60 vs 1/30).
        while accumulator >= dt - 1e-9 {
            replay.record(pending, at: world.tick)
            frameEvents += Simulation.step(&world, commands: pending)
            pending.removeAll(keepingCapacity: true)
            accumulator -= dt
            if world.isOver { break }
        }
        accumulator = max(accumulator, 0)
        alpha = Float(accumulator / dt)
        let updated = HUDState(world)
        if updated != hud { hud = updated }
    }

    /// Starts a fresh game on the same map and mode.
    public func restart(seed: UInt64) {
        world = World(level: world.level, profile: world.profile, seed: seed)
        replay = Replay(levelID: world.level.id, profileID: world.profile.id, seed: seed)
        pending.removeAll()
        accumulator = 0
        alpha = 0
        frameEvents.removeAll()
        isPaused = false
        hud = HUDState(world)
    }

    /// Swaps in a prepared world. For tests and debug tools.
    func replaceWorld(_ world: World) {
        self.world = world
        hud = HUDState(world)
    }
}

/// The handful of values the HUD shows.
public struct HUDState: Equatable, Sendable {
    public var landed: Int
    public var strikesLeft: Int
    public var conflicts: Int
    public var isOver: Bool
    /// Whole seconds played.
    public var seconds: Int

    public init(_ world: World) {
        landed = world.landed
        strikesLeft = world.strikesLeft
        conflicts = world.conflicts.count
        isOver = world.isOver
        seconds = Int(world.time)
    }
}
