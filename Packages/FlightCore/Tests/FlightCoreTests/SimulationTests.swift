import Testing

@testable import FlightCore

struct MovementTests {
    @Test func unguidedAircraftFliesStraight() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        world.run(seconds: 2)
        let plane = try #require(world.aircraft(id))
        #expect(plane.position.x.isApproximately(34, tolerance: 0.2))
        #expect(plane.position.y.isApproximately(50))
    }

    @Test func turnsNeverExceedTheKindsLimit() throws {
        var world = Fixtures.world()
        let id = world.place(.jet, at: Vec2(80, 50))
        world.draw(id, through: Fixtures.line(from: Vec2(81, 50), to: Vec2(81, 20)))
        let limit = AircraftKind.jet.spec.maxTurnRate * Simulation.dt + 0.0001
        for _ in 0..<120 {
            let before = try #require(world.aircraft(id)).heading
            Simulation.step(&world, commands: [])
            let after = try #require(world.aircraft(id)).heading
            #expect(abs(Angles.delta(from: before, to: after)) <= limit)
        }
    }

    @Test func aircraftTurnBackAtTheEdge() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(150, 50))
        for _ in 0..<(60 * 20) {
            Simulation.step(&world, commands: [])
            guard let plane = world.aircraft(id) else { break }
            #expect(world.level.contains(plane.position, inset: -2))
        }
    }

    @Test func pathIsFollowedAndDroppedAtTheEnd() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        world.draw(id, through: Fixtures.line(from: Vec2(21, 50), to: Vec2(50, 80)))
        world.run(seconds: 8)
        let plane = try #require(world.aircraft(id))
        #expect(plane.path == nil)
        // It ended up near the end of the path and carried on its last heading.
        #expect(plane.position.y > 75)
    }
}

struct FlightLevelTests {
    @Test func climbsAtTheKindsRate() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        let events = world.run(seconds: 3, commands: [.setLevel(id, 3)])
        #expect(events.contains(.levelChanged(id, level: 3)))
        #expect(try #require(world.aircraft(id)).altitude.isApproximately(2, tolerance: 0.02))
        world.run(seconds: 4)
        #expect(try #require(world.aircraft(id)).altitude == 3)
    }

    @Test func helicoptersStopAtTheirCeiling() throws {
        var world = Fixtures.world()
        let id = world.place(.heli, at: Vec2(20, 50))
        world.run(seconds: 1, commands: [.setLevel(id, 3)])
        #expect(try #require(world.aircraft(id)).targetLevel == 2)
    }

    @Test func differentLevelsPassSafely() {
        var world = Fixtures.world()
        world.place(.prop, at: Vec2(40, 50), heading: 0, level: 1)
        world.place(.prop, at: Vec2(80, 50), heading: .pi, level: 2)
        let events = world.run(seconds: 6)
        #expect(world.phase == .playing)
        #expect(!events.contains { if case .conflictBegan = $0 { true } else { false } })
    }

    @Test func sameLevelHeadOnCrashes() {
        var world = Fixtures.world()
        world.place(.prop, at: Vec2(40, 50), heading: 0)
        world.place(.prop, at: Vec2(80, 50), heading: .pi)
        let events = world.run(seconds: 6)
        #expect(events.contains { if case .conflictBegan = $0 { true } else { false } })
        #expect(events.contains { if case .gameOver(.midair) = $0 { true } else { false } })
        #expect(world.isOver)
    }

    @Test func conflictWarningHasHysteresis() {
        var world = Fixtures.world()
        let a = world.place(.prop, at: Vec2(40, 50), heading: 0)
        let b = world.place(.prop, at: Vec2(40, 58), heading: 0)
        var events = world.run(seconds: 0.1)
        let pair = AircraftPair(a, b)
        #expect(events.contains(.conflictBegan(pair)))
        // Drift apart to 10.5: past the warning distance (10) but inside the release distance (11).
        world.aircraft[1].position.y = 60.5
        events = world.run(seconds: 0.1)
        #expect(world.conflicts.contains(pair))
        world.aircraft[1].position.y = 62
        events = world.run(seconds: 0.1)
        #expect(events.contains(.conflictEnded(pair)))
    }

    @Test func lowAircraftHitTerrainHighOnesFlyOver() {
        var low = Fixtures.world()
        low.place(.prop, at: Vec2(90, 30), heading: 0, level: 2)
        let events = low.run(seconds: 4)
        #expect(events.contains { if case .gameOver(.terrain) = $0 { true } else { false } })

        var high = Fixtures.world()
        high.place(.prop, at: Vec2(90, 30), heading: 0, level: 3)
        high.run(seconds: 4)
        #expect(high.phase == .playing)
    }
}

struct LandingTests {
    @Test func committedAircraftLandsAndScores() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 70))
        var events = world.draw(id, through: Fixtures.line(from: Vec2(21, 70), to: Vec2(59, 70)))
        events += world.run(seconds: 6.5)
        #expect(events.contains(.touchedDown(id, "short")))
        // Scored at touchdown, removed after the roll-out.
        #expect(world.landed == 1)
        events += world.run(seconds: 7)
        #expect(events.contains(.landed(id)))
        #expect(world.aircraft(id) == nil)
    }

    @Test func descendsFromHighUpBeforeTouchingDown() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(2, 70), level: 3)
        world.draw(id, through: Fixtures.line(from: Vec2(3, 70), to: Vec2(59, 70)))
        var lowestBeforeTouchdown: Float = 3
        for _ in 0..<(60 * 12) {
            let events = Simulation.step(&world, commands: [])
            if let plane = world.aircraft(id), plane.isFlying {
                lowestBeforeTouchdown = min(lowestBeforeTouchdown, plane.altitude)
            }
            if events.contains(.touchedDown(id, "short")) { break }
        }
        #expect(world.landed == 1)
        #expect(lowestBeforeTouchdown < 0.5)
    }

    @Test func helicopterLandsFromAnyDirection() {
        var world = Fixtures.world()
        let id = world.place(.heli, at: Vec2(130, 95), heading: -.pi / 2)
        let events = world.draw(id, through: Fixtures.line(from: Vec2(130, 94), to: Vec2(130, 71)))
        #expect(events.contains(.pathCommitted(id, "pad")))
        world.run(seconds: 10)
        #expect(world.landed == 1)
    }

    @Test func landingAircraftCannotCollide() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 70))
        world.draw(id, through: Fixtures.line(from: Vec2(21, 70), to: Vec2(59, 70)))
        world.run(seconds: 6.5)
        #expect(world.aircraft(id).map { !$0.isFlying } == true)
        // Park another aircraft right on the runway, at the ground, heading the same way.
        world.place(.prop, at: world.aircraft(id)!.position + Vec2(2, 0), heading: 0, level: 1)
        world.run(seconds: 0.2)
        #expect(world.phase == .playing)
    }
}

struct StrikeTests {
    @Test func relaxedCrashCostsAStrikeAndRemovesBoth() {
        var world = Fixtures.world(Fixtures.quietRelaxed)
        world.place(.prop, at: Vec2(40, 50), heading: 0)
        world.place(.prop, at: Vec2(80, 50), heading: .pi)
        let events = world.run(seconds: 6)
        #expect(events.contains { if case .crashed(.midair) = $0 { true } else { false } })
        #expect(world.strikesLeft == 2)
        #expect(world.phase == .playing)
        #expect(world.aircraft.isEmpty)
        #expect(world.conflicts.isEmpty)
    }
}
