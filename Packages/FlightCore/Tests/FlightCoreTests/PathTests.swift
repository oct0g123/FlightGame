import Testing

@testable import FlightCore

struct PathTests {
    @Test func pointsAreEvenlySpaced() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        world.draw(id, through: Fixtures.line(from: Vec2(20, 50), to: Vec2(70, 55)))
        let points = try #require(world.aircraft(id)?.path?.points)
        #expect(points.count > 40)
        for (a, b) in zip(points, points.dropFirst()).dropLast() {
            #expect(a.distance(to: b).isApproximately(FlightPath.spacing))
        }
    }

    @Test func pathsStayInsideTheField() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        world.draw(id, through: Fixtures.line(from: Vec2(20, 50), to: Vec2(-40, 50)))
        let points = try #require(world.aircraft(id)?.path?.points)
        #expect(points.allSatisfy { $0.x >= 1 })
    }

    @Test func alignedPathToMatchingRunwayCommits() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 70))
        let events = world.draw(id, through: Fixtures.line(from: Vec2(21, 70), to: Vec2(59, 70)))
        #expect(events.contains(.pathCommitted(id, "short")))
        let path = try #require(world.aircraft(id)?.path)
        #expect(path.committedRunway == "short")
        #expect(path.points.last == Vec2(60, 70))
        #expect(!path.isDrawing)
    }

    @Test func wrongRunwayIsRejectedOnce() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(10, 30))
        var events = Simulation.step(
            &world,
            commands: [
                .startPath(id, at: Vec2(11, 30)),
                .extendPath(
                    id, points: Fixtures.line(from: Vec2(11, 30), to: Vec2(39, 30)), level: nil),
            ])
        events += Simulation.step(
            &world,
            commands: [
                .extendPath(id, points: [Vec2(41, 30), Vec2(43, 30)], level: nil)
            ])
        let rejections = events.filter {
            if case .pathRejected(id, _, .wrongRunway) = $0 { return true }
            return false
        }
        #expect(rejections.count == 1)
        #expect(world.aircraft(id)?.path?.isCommitted == false)
    }

    @Test func pathAgainstTheRunwayHeadingDoesNotCommit() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(100, 70), heading: .pi)
        let events = world.draw(id, through: Fixtures.line(from: Vec2(99, 70), to: Vec2(61, 70)))
        #expect(!events.contains { if case .pathCommitted = $0 { true } else { false } })
        #expect(!events.contains { if case .pathRejected = $0 { true } else { false } })
    }

    @Test func shortPathFromHighUpIsTooHigh() {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(44, 70), level: 3)
        let events = world.draw(id, through: Fixtures.line(from: Vec2(45, 70), to: Vec2(59, 70)))
        #expect(
            events.contains { if case .pathRejected(id, _, .tooHigh) = $0 { true } else { false } })
        #expect(world.aircraft(id)?.path?.isCommitted == false)
    }

    @Test func longPathFromHighUpPlansALateDescent() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(2, 70), level: 3)
        let events = world.draw(id, through: Fixtures.line(from: Vec2(3, 70), to: Vec2(59, 70)))
        #expect(events.contains(.pathCommitted(id, "short")))
        let path = try #require(world.aircraft(id)?.path)
        let mark = try #require(path.levelMarks.last)
        #expect(mark.level == 1)
        // Two levels at 1/3 level per second and 7 units per second, plus the final glide.
        let needed = 2 / AircraftKind.prop.spec.climbRate * 7 + Simulation.finalGlide
        #expect(path.points.count - 1 - mark.index == Int(needed.rounded(.up)))
    }

    @Test func handHeightAddsLevelMarks() throws {
        var world = Fixtures.world()
        let id = world.place(.prop, at: Vec2(20, 50))
        Simulation.step(
            &world,
            commands: [
                .startPath(id, at: Vec2(21, 50)),
                .extendPath(
                    id, points: Fixtures.line(from: Vec2(21, 50), to: Vec2(40, 50)), level: 1),
                .extendPath(
                    id, points: Fixtures.line(from: Vec2(40, 50), to: Vec2(60, 50)), level: 3),
                .extendPath(
                    id, points: Fixtures.line(from: Vec2(60, 50), to: Vec2(80, 50)), level: 3),
            ])
        let marks = try #require(world.aircraft(id)?.path?.levelMarks)
        // Level 1 is the current level, so only the change to 3 is marked.
        #expect(marks.map(\.level) == [3])
    }
}
