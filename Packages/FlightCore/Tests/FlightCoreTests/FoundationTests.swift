import Foundation
import Testing

@testable import FlightCore

struct MathTests {
    @Test func vectorBasics() {
        let a = Vec2(3, 4)
        #expect(a.length == 5)
        #expect(a.normalized.length.isApproximately(1))
        #expect((a - Vec2(1, 1)) == Vec2(2, 3))
        #expect(Vec2(heading: .pi / 2).x.isApproximately(0))
        #expect(Vec2(0, 2).heading.isApproximately(.pi / 2))
        #expect(Vec2.zero.normalized == .zero)
    }

    @Test func vectorEncodesAsPair() throws {
        let data = try JSONEncoder().encode(Vec2(1.5, -2))
        #expect(String(decoding: data, as: UTF8.self) == "[1.5,-2]")
        #expect(try JSONDecoder().decode(Vec2.self, from: data) == Vec2(1.5, -2))
    }

    @Test func anglesWrapToTheShortWay() {
        #expect(Angles.wrap(3 * .pi + 0.5).isApproximately(-.pi + 0.5))
        #expect(Angles.wrap(-.pi) == .pi)
        #expect(
            Angles.delta(
                from: Angles.radians(fromDegrees: 170), to: Angles.radians(fromDegrees: -170)
            )
            .isApproximately(Angles.radians(fromDegrees: 20)))
    }
}

struct RandomTests {
    /// Reference values from an independent implementation of SplitMix64 and
    /// xoshiro256**. If these change, every seed and replay changes too.
    @Test func matchesReferenceOutput() {
        var mixer = SplitMix64(state: 0)
        #expect(mixer.next() == 0xE220_A839_7B1D_CDAF)
        #expect(mixer.next() == 0x6E78_9E6A_A1B9_65F4)

        var random = Xoshiro256(seed: 42)
        #expect(random.next() == 0x1578_0B2E_0C2E_C716)
        #expect(random.next() == 0x6104_D986_6D11_3A7E)
        #expect(random.next() == 0xAE17_5332_39E4_99A1)
    }

    @Test func helpersStayInRange() {
        var random = Xoshiro256(seed: 7)
        for _ in 0..<10_000 {
            let unit = random.nextUnit()
            #expect(unit >= 0 && unit < 1)
            let int = random.nextInt(below: 3)
            #expect((0..<3).contains(int))
        }
    }

    @Test func streamsAreIndependent() {
        var streams = RandomStreams(seed: 9)
        #expect(streams.schedule.next() != streams.fairness.next())
    }
}

struct ContentTests {
    @Test(arguments: BuiltInContent.levelIDs)
    func bundledLevelIsValid(id: String) throws {
        let level = try BuiltInContent.level(id)
        #expect(level.id == id)
        #expect(level.problems() == [])
        #expect(!level.profiles.isEmpty)
        for profileID in level.profiles {
            let profile = try BuiltInContent.profile(profileID)
            // Every kind the profile sends must have somewhere to land.
            for step in profile.mix {
                for entry in step.weights {
                    #expect(
                        level.runways.contains { $0.accepts(entry.kind) },
                        "\(id) has no runway for \(entry.kind) in \(profileID)")
                }
            }
        }
    }

    @Test func coastalFieldIsSingleLevel() throws {
        let level = try BuiltInContent.level("coastal-field")
        #expect(level.flightLevels == 1)
        #expect(level.runways.count == 3)
        let short = try #require(level.runway("short"))
        #expect(short.heading.isApproximately(.pi / 4))
        #expect(short.headingTolerance.isApproximately(Angles.radians(fromDegrees: 35)))
        #expect(level.runway("pad")?.anyHeading == true)
    }

    @Test func testRangeHasLevelsAndTerrain() throws {
        let level = try BuiltInContent.level("test-range")
        #expect(level.flightLevels == 3)
        #expect(level.noFlyZones.map(\.ceiling) == [2, 1])
    }

    @Test func classicProfileCurves() throws {
        let profile = try BuiltInContent.profile("classic")
        #expect(profile.spawnInterval.value(at: 0).isApproximately(6))
        #expect(profile.spawnInterval.value(at: 90).isApproximately(3.8))
        #expect(profile.maxAirborne.value(at: 30).isApproximately(4.5))
        #expect(profile.maxAirborne.value(at: 999).isApproximately(16))
        #expect(profile.weights(at: 0).map(\.kind) == [.prop])
        #expect(profile.weights(at: 100).map(\.kind) == [.prop, .jet, .heli])
        #expect(profile.arrivalLevels[.jet] == [2, 3])
        #expect(profile.strikes == 1)
        #expect(try BuiltInContent.profile("relaxed").strikes == 3)
    }

    @Test func missingContentThrows() {
        #expect(throws: ContentError.missing("Levels/nowhere.json")) {
            try BuiltInContent.level("nowhere")
        }
    }

    @Test func validationCatchesMistakes() {
        let broken = Level(
            id: "broken", name: "Broken", size: Vec2(100, 100), flightLevels: 2,
            runways: [
                Runway(
                    id: "a", accepts: [.prop], threshold: Vec2(90, 50), length: 30, captureRadius: 5
                )
            ],
            noFlyZones: [NoFlyZone(id: "z", center: Vec2(50, 50), radius: 5, ceiling: 2)]
        )
        let problems = broken.problems()
        #expect(problems.contains("runway a is outside the field"))
        #expect(problems.contains("no-fly zone z must leave a level above it clear"))
    }
}

extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.001) -> Bool {
        abs(self - other) <= tolerance
    }
}
