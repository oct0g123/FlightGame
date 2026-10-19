import Foundation

/// How a mode gets harder over time. Decoded from `Resources/Difficulty`.
public struct DifficultyProfile: Identifiable, Sendable {
    public let id: String
    /// Seconds between arrivals.
    public let spawnInterval: Decay
    /// Most aircraft allowed in the air (or announced) at once.
    public let maxAirborne: Curve
    /// Which kinds arrive, changing at set times.
    public let mix: [MixStep]
    /// Multiplier on every aircraft's speed when it arrives.
    public let speedScale: Curve
    /// Flight levels each kind can arrive at, before limiting to the map's levels.
    public let arrivalLevels: [AircraftKind: [Int]]
    /// Seconds of warning before an arrival appears.
    public let warningLead: Float
    /// Crashes allowed before the game ends.
    public let strikes: Int

    public init(
        id: String, spawnInterval: Decay, maxAirborne: Curve, mix: [MixStep],
        speedScale: Curve = Curve([(0, 1)]), arrivalLevels: [AircraftKind: [Int]] = [:],
        warningLead: Float = 2, strikes: Int = 1
    ) {
        self.id = id
        self.spawnInterval = spawnInterval
        self.maxAirborne = maxAirborne
        self.mix = mix.sorted { $0.time < $1.time }
        self.speedScale = speedScale
        self.arrivalLevels = arrivalLevels
        self.warningLead = warningLead
        self.strikes = strikes
    }

    /// The kind weights in effect at time `t`, in `AircraftKind.allCases` order.
    public func weights(at t: Float) -> [(kind: AircraftKind, weight: Float)] {
        (mix.last { $0.time <= t } ?? mix.first)?.weights ?? [(.prop, 1)]
    }
}

/// Exponential approach from `start` to `end`, halving the gap every `halfLife` seconds.
public struct Decay: Decodable, Sendable {
    public let start: Float
    public let end: Float
    public let halfLife: Float

    public init(start: Float, end: Float, halfLife: Float) {
        self.start = start
        self.end = end
        self.halfLife = halfLife
    }

    public func value(at t: Float) -> Float {
        end + (start - end) * pow(0.5, max(t, 0) / halfLife)
    }
}

/// A piecewise-linear curve through `(time, value)` points, flat beyond the ends.
/// JSON: `[[0, 3], [60, 6]]`.
public struct Curve: Decodable, Sendable {
    public let points: [(time: Float, value: Float)]

    public init(_ points: [(time: Float, value: Float)]) {
        self.points = points.sorted { $0.time < $1.time }
    }

    public init(from decoder: any Decoder) throws {
        let pairs = try [[Float]](from: decoder)
        guard pairs.allSatisfy({ $0.count == 2 }), !pairs.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath, debugDescription: "Expected [[time, value], …]")
            )
        }
        self.init(pairs.map { (time: $0[0], value: $0[1]) })
    }

    public func value(at t: Float) -> Float {
        guard let first = points.first, let last = points.last else { return 0 }
        if t <= first.time { return first.value }
        if t >= last.time { return last.value }
        let upper = points.firstIndex { $0.time > t } ?? points.count - 1
        let a = points[upper - 1]
        let b = points[upper]
        return a.value + (b.value - a.value) * (t - a.time) / (b.time - a.time)
    }
}

/// From `time` onward, kinds arrive in proportion to `weights`.
/// JSON: `[30, {"prop": 0.6, "jet": 0.4}]`.
public struct MixStep: Decodable, Sendable {
    public let time: Float
    public let weights: [(kind: AircraftKind, weight: Float)]

    public init(time: Float, weights: [AircraftKind: Float]) {
        self.time = time
        // Fixed order, so the same random roll always picks the same kind.
        self.weights = AircraftKind.allCases.compactMap { kind in
            weights[kind].map { (kind: kind, weight: $0) }
        }
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let time = try container.decode(Float.self)
        let raw = try container.decode([String: Float].self)
        var weights: [AircraftKind: Float] = [:]
        for (name, weight) in raw {
            guard let kind = AircraftKind(rawValue: name) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unknown aircraft kind \(name)")
            }
            weights[kind] = weight
        }
        self.init(time: time, weights: weights)
    }
}

extension DifficultyProfile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, spawnInterval, maxAirborne, mix, speedScale, arrivalLevels, warningLead, strikes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawLevels =
            try container.decodeIfPresent([String: [Int]].self, forKey: .arrivalLevels) ?? [:]
        var arrivalLevels: [AircraftKind: [Int]] = [:]
        for (name, levels) in rawLevels {
            if let kind = AircraftKind(rawValue: name) { arrivalLevels[kind] = levels }
        }
        self.init(
            id: try container.decode(String.self, forKey: .id),
            spawnInterval: try container.decode(Decay.self, forKey: .spawnInterval),
            maxAirborne: try container.decode(Curve.self, forKey: .maxAirborne),
            mix: try container.decode([MixStep].self, forKey: .mix),
            speedScale: try container.decodeIfPresent(Curve.self, forKey: .speedScale)
                ?? Curve([(0, 1)]),
            arrivalLevels: arrivalLevels,
            warningLead: try container.decodeIfPresent(Float.self, forKey: .warningLead) ?? 2,
            strikes: try container.decodeIfPresent(Int.self, forKey: .strikes) ?? 1
        )
    }
}
