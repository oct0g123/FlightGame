import Testing

@testable import FlightCore

struct SpawnerTests {
    func arrivals(level: String, seeds: ClosedRange<UInt64>, seconds: Float) throws
        -> [PendingArrival]
    {
        let level = try BuiltInContent.level(level)
        let profile = try BuiltInContent.profile("relaxed")
        var all: [PendingArrival] = []
        for seed in seeds {
            var world = World(level: level, profile: profile, seed: seed)
            for _ in 0..<Int(seconds / Simulation.dt) {
                for event in Simulation.step(&world, commands: []) {
                    if case .arrivalWarning(let arrival) = event { all.append(arrival) }
                }
                if world.isOver { break }
            }
        }
        return all
    }

    @Test func arrivalIsAnnouncedBeforeItAppears() throws {
        var world = World(
            level: Fixtures.level, profile: try BuiltInContent.profile("classic"), seed: 3)
        var warnedAt: Float?
        var spawnedAt: Float?
        for _ in 0..<(60 * 10) {
            for event in Simulation.step(&world, commands: []) {
                if case .arrivalWarning = event, warnedAt == nil { warnedAt = world.time }
                if case .spawned = event, spawnedAt == nil { spawnedAt = world.time }
            }
        }
        let warned = try #require(warnedAt)
        let spawned = try #require(spawnedAt)
        #expect(spawned - warned >= 1.9)
        let plane = try #require(world.aircraft.first)
        #expect(plane.kind == .prop)
    }

    @Test func arrivalsStartOutsideTheField() throws {
        for arrival in try arrivals(level: "coastal-field", seeds: 1...5, seconds: 60) {
            let level = try BuiltInContent.level("coastal-field")
            #expect(!level.contains(arrival.entry))
            #expect(level.contains(arrival.entry, inset: -World.entryDistance - 0.01))
        }
    }

    @Test func singleLevelMapOnlyUsesLevelOne() throws {
        let all = try arrivals(level: "coastal-field", seeds: 1...8, seconds: 150)
        #expect(all.count > 20)
        #expect(all.allSatisfy { $0.level == 1 })
    }

    @Test func multiLevelMapUsesEachKindsArrivalLevels() throws {
        let all = try arrivals(level: "test-range", seeds: 1...8, seconds: 150)
        #expect(all.contains { $0.kind == .jet })
        for arrival in all {
            switch arrival.kind {
            case .prop: #expect([1, 2].contains(arrival.level))
            case .jet: #expect([2, 3].contains(arrival.level))
            case .heli: #expect(arrival.level == 1)
            }
        }
    }

    @Test func announcedArrivalsKeepApart() throws {
        let level = try BuiltInContent.level("coastal-field")
        var world = World(level: level, profile: try BuiltInContent.profile("classic"), seed: 11)
        for _ in 0..<(60 * 120) {
            Simulation.step(&world, commands: [])
            for (n, a) in world.pendingArrivals.enumerated() {
                for b in world.pendingArrivals[(n + 1)...] {
                    #expect(a.entry.distance(to: b.entry) >= 25)
                }
            }
            if world.isOver { break }
        }
    }

    @Test func sameSeedSameScript() throws {
        let a = try arrivals(level: "test-range", seeds: 42...42, seconds: 60)
        let b = try arrivals(level: "test-range", seeds: 42...42, seconds: 60)
        #expect(a == b)
        let c = try arrivals(level: "test-range", seeds: 43...43, seconds: 60)
        #expect(a != c)
    }

    @Test func respectsMaxAirborne() throws {
        let level = try BuiltInContent.level("coastal-field")
        let profile = try BuiltInContent.profile("relaxed")
        var world = World(level: level, profile: profile, seed: 5)
        for _ in 0..<(60 * 200) {
            Simulation.step(&world, commands: [])
            let airborne = world.aircraft.count { $0.isFlying } + world.pendingArrivals.count
            #expect(airborne <= Int(profile.maxAirborne.value(at: world.time)) + 1)
            if world.isOver { break }
        }
    }
}
