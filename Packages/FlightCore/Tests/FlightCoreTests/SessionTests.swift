import Foundation
import Testing

@testable import FlightCore

@MainActor
struct GameSessionTests {
    func session() -> GameSession {
        GameSession(level: Fixtures.level, profile: Fixtures.quiet, seed: 1)
    }

    @Test func runsFixedTicksAndCarriesTheRemainder() {
        let session = session()
        session.advance(by: 1.0 / 30)
        #expect(session.world.tick == 2)
        session.advance(by: 1.0 / 120)
        #expect(session.world.tick == 2)
        #expect(session.alpha.isApproximately(0.5, tolerance: 0.01))
        session.advance(by: 1.0 / 120)
        #expect(session.world.tick == 3)
    }

    @Test func clampsLongHitches() {
        let session = session()
        session.advance(by: 5)
        #expect(
            session.world.tick == UInt64((GameSession.maxStep / Double(Simulation.dt)).rounded()))
    }

    @Test func pausingStopsTheClock() {
        let session = session()
        session.isPaused = true
        session.advance(by: 0.1)
        #expect(session.world.tick == 0)
    }

    @Test func commandsApplyOnTheNextTickAndAreRecorded() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        let session = session()
        session.inject(world)
        session.send(.setLevel(id, 2))
        session.advance(by: 1.0 / 60)
        #expect(session.frameEvents.contains(.levelChanged(id, level: 2)))
        #expect(session.replay.entries.count == 1)
        #expect(session.replay.entries.first?.commands == [.setLevel(id, 2)])
    }

    @Test func hudFollowsTheGame() {
        var world = Fixtures.world()
        world.place(.prop, at: Vec2(40, 50), heading: 0)
        world.place(.prop, at: Vec2(80, 50), heading: .pi)
        let session = session()
        session.inject(world)
        for _ in 0..<(60 * 6) { session.advance(by: 1.0 / 60) }
        #expect(session.hud.isOver)
        #expect(session.hud.strikesLeft == 0)
        session.restart(seed: 2)
        #expect(!session.hud.isOver)
        #expect(session.world.aircraft.isEmpty)
    }
}

extension GameSession {
    /// Replaces the world, for tests that set up aircraft by hand.
    func inject(_ world: World) {
        restart(seed: world.seed)
        replaceWorld(world)
    }
}

struct PathDrawingControllerTests {
    func world() -> (World, AircraftID, AircraftID) {
        var world = Fixtures.world()
        let near = world.place(.prop, at: Vec2(50, 50))
        let far = world.place(.jet, at: Vec2(70, 50))
        return (world, near, far)
    }

    @Test func tapWithoutDraggingIsATap() {
        let (world, near, _) = world()
        var controller = PathDrawingController()
        #expect(
            controller.handle(PointerEvent(id: 1, phase: .began, location: Vec2(52, 51)), in: world)
                == [])
        #expect(
            controller.handle(
                PointerEvent(id: 1, phase: .moved, location: Vec2(52.5, 51)), in: world) == [])
        #expect(
            controller.handle(
                PointerEvent(id: 1, phase: .ended, location: Vec2(52.5, 51)), in: world)
                == [.tapped(near)])
    }

    @Test func draggingDrawsAPath() {
        let (world, near, _) = world()
        var controller = PathDrawingController()
        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: Vec2(51, 50)), in: world)
        let outputs = controller.handle(
            PointerEvent(id: 1, phase: .moved, location: Vec2(55, 50)), in: world)
        #expect(
            outputs == [
                .command(.startPath(near, at: Vec2(51, 50))),
                .command(.extendPath(near, points: [Vec2(55, 50)], level: nil)),
            ])
        #expect(
            controller.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(55, 50)), in: world)
                == [.command(.finishPath(near))])
    }

    @Test func grabsTheNearestFreeAircraftWithinReach() {
        let (world, near, far) = world()
        var controller = PathDrawingController(grabRadius: 12.5)
        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: Vec2(58, 50)), in: world)
        #expect(controller.heldAircraft == [near])
        // A second finger within reach of both gets the one that isn't already held.
        _ = controller.handle(PointerEvent(id: 2, phase: .began, location: Vec2(58, 50)), in: world)
        #expect(controller.heldAircraft == [near, far])
        // Nothing within reach.
        _ = controller.handle(PointerEvent(id: 3, phase: .began, location: Vec2(10, 90)), in: world)
        #expect(controller.heldAircraft.count == 2)
    }

    @Test func handHeightPicksLevelsWithHysteresis() {
        let (world, near, _) = world()
        var controller = PathDrawingController()
        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: Vec2(50, 50)), in: world)
        func level(at height: Float, x: Float) -> Int? {
            let outputs = controller.handle(
                PointerEvent(id: 1, phase: .moved, location: Vec2(x, 50), height: height), in: world
            )
            guard case .command(.extendPath(near, _, let level)) = outputs.last else { return nil }
            return level
        }
        #expect(level(at: 0.1, x: 55) == 1)
        #expect(level(at: 0.6, x: 56) == 1)  // inside the hysteresis band
        #expect(level(at: 0.7, x: 57) == 2)
        #expect(level(at: 0.4, x: 58) == 2)  // stays until clearly back down
        #expect(level(at: 5, x: 59) == 3)  // capped at the map's top level
        #expect(level(at: -3, x: 60) == 1)
    }
}

struct AutopilotTests {
    @Test func landsTrafficOnBothMaps() throws {
        for id in BuiltInContent.levelIDs {
            var world = World(
                level: try BuiltInContent.level(id), profile: try BuiltInContent.profile("relaxed"),
                seed: 21)
            var pilot = Autopilot()
            for _ in 0..<(60 * 120) {
                Simulation.step(&world, commands: pilot.commands(for: world))
                if world.isOver { break }
            }
            #expect(world.landed >= 3, "autopilot landed only \(world.landed) on \(id)")
        }
    }
}

struct DeterminismTests {
    func play(seed: UInt64, seconds: Float) throws -> (World, Replay) {
        let level = try BuiltInContent.level("test-range")
        let profile = try BuiltInContent.profile("classic")
        var world = World(level: level, profile: profile, seed: seed)
        var replay = Replay(levelID: level.id, profileID: profile.id, seed: seed)
        var pilot = Autopilot()
        for _ in 0..<Int(seconds / Simulation.dt) {
            let commands = pilot.commands(for: world)
            replay.record(commands, at: world.tick)
            Simulation.step(&world, commands: commands)
            if world.isOver { break }
        }
        return (world, replay)
    }

    @Test func sameSeedAndCommandsGiveTheSameGame() throws {
        let (a, _) = try play(seed: 7, seconds: 120)
        let (b, _) = try play(seed: 7, seconds: 120)
        #expect(a.fingerprint == b.fingerprint)
        let (c, _) = try play(seed: 8, seconds: 120)
        #expect(a.fingerprint != c.fingerprint)
    }

    @Test func replayReproducesTheGame() throws {
        let (original, replay) = try play(seed: 7, seconds: 120)
        let replayed = replay.play(
            level: try BuiltInContent.level(replay.levelID),
            profile: try BuiltInContent.profile(replay.profileID),
            ticks: original.tick)
        #expect(replayed.fingerprint == original.fingerprint)
        #expect(replayed.landed == original.landed)
    }

    @Test func replayRoundTripsThroughJSON() throws {
        let (_, replay) = try play(seed: 3, seconds: 30)
        #expect(!replay.entries.isEmpty)
        let decoded = try JSONDecoder().decode(Replay.self, from: JSONEncoder().encode(replay))
        #expect(decoded == replay)
    }
}

struct SoakTests {
    /// Ten minutes of autopilot play per map, restarting after each crash,
    /// checking the state stays sane every tick.
    @Test(arguments: BuiltInContent.levelIDs)
    func longPlayStaysSane(levelID: String) throws {
        let level = try BuiltInContent.level(levelID)
        let profile = try BuiltInContent.profile("classic")
        var seed: UInt64 = 100
        var world = World(level: level, profile: profile, seed: seed)
        var pilot = Autopilot()
        var landed = 0
        for _ in 0..<(60 * 600) {
            Simulation.step(&world, commands: pilot.commands(for: world))
            for plane in world.aircraft {
                #expect(plane.position.x.isFinite && plane.position.y.isFinite)
                #expect(plane.altitude >= 0 && plane.altitude <= Float(level.flightLevels))
                #expect(level.contains(plane.position, inset: -12), "\(plane.id) left the field")
            }
            let flying = world.aircraft.count { $0.isFlying }
            #expect(
                flying + world.pendingArrivals.count <= Int(
                    profile.maxAirborne.value(at: world.time)) + 1)
            if world.isOver {
                landed += world.landed
                seed += 1
                world = World(level: level, profile: profile, seed: seed)
                pilot = Autopilot()
            }
        }
        landed += world.landed
        #expect(landed > 20, "only \(landed) landings in ten minutes on \(levelID)")
    }
}
