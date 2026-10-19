import Foundation

public typealias RunwayID = String

/// A map: the playfield, its runways, flight levels and obstacles.
///
/// Decoded from the JSON files in `Resources/Levels`. Headings and tolerances
/// are degrees in JSON and radians in memory.
public struct Level: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Width and height of the playfield, in field units.
    public let size: Vec2
    /// How many flight levels are stacked above the ground (1–3).
    public let flightLevels: Int
    public let runways: [Runway]
    public let noFlyZones: [NoFlyZone]
    public let spawnEdges: [Edge]
    /// Difficulty profiles this map can be played with.
    public let profiles: [String]

    public init(
        id: String, name: String, size: Vec2, flightLevels: Int, runways: [Runway],
        noFlyZones: [NoFlyZone] = [], spawnEdges: [Edge] = Edge.allCases,
        profiles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.flightLevels = flightLevels
        self.runways = runways
        self.noFlyZones = noFlyZones
        self.spawnEdges = spawnEdges
        self.profiles = profiles
    }

    public var center: Vec2 { size / 2 }

    public func runway(_ id: RunwayID) -> Runway? { runways.first { $0.id == id } }

    /// Whether `point` is inside the playfield, shrunk by `inset` on every side.
    public func contains(_ point: Vec2, inset: Float = 0) -> Bool {
        point.x >= inset && point.x <= size.x - inset && point.y >= inset
            && point.y <= size.y - inset
    }

    /// The nearest point to `point` inside the playfield, shrunk by `inset`.
    public func clamp(_ point: Vec2, inset: Float = 0) -> Vec2 {
        Vec2(min(max(point.x, inset), size.x - inset), min(max(point.y, inset), size.y - inset))
    }

    /// Highest level an aircraft of this kind can use on this map.
    public func ceiling(for kind: AircraftKind) -> Int { min(flightLevels, kind.spec.ceiling) }

    /// Mistakes that would make the map unplayable. Empty when the map is fine.
    public func problems() -> [String] {
        var problems: [String] = []
        if !(1...3).contains(flightLevels) { problems.append("flightLevels must be 1–3") }
        if runways.isEmpty { problems.append("no runways") }
        if spawnEdges.isEmpty { problems.append("no spawn edges") }
        if Set(runways.map(\.id)).count != runways.count { problems.append("duplicate runway ids") }
        for runway in runways {
            if !contains(runway.threshold) || !contains(runway.end) {
                problems.append("runway \(runway.id) is outside the field")
            }
            if runway.accepts.isEmpty { problems.append("runway \(runway.id) accepts nothing") }
            if runway.captureRadius <= 0 {
                problems.append("runway \(runway.id) has no capture zone")
            }
        }
        for zone in noFlyZones {
            if zone.ceiling < 1 || zone.ceiling >= flightLevels {
                problems.append("no-fly zone \(zone.id) must leave a level above it clear")
            }
            for runway in runways where zone.overlaps(runway) {
                problems.append("no-fly zone \(zone.id) blocks runway \(runway.id)")
            }
        }
        return problems
    }
}

/// A runway, or a helipad when `anyHeading` is true.
public struct Runway: Identifiable, Sendable {
    public let id: RunwayID
    public let accepts: Set<AircraftKind>
    /// Where aircraft touch down.
    public let threshold: Vec2
    /// Direction of the landing roll, in radians.
    public let heading: Float
    /// Length of the landing roll. Zero for a helipad.
    public let length: Float
    /// A path ending within this distance of the threshold can lock on.
    public let captureRadius: Float
    /// How far the end of a path may point away from `heading`, in radians.
    public let headingTolerance: Float
    /// Helipads accept an approach from any direction.
    public let anyHeading: Bool

    public init(
        id: RunwayID, accepts: Set<AircraftKind>, threshold: Vec2, heading: Float = 0,
        length: Float = 0, captureRadius: Float,
        headingTolerance: Float = Angles.radians(fromDegrees: 35),
        anyHeading: Bool = false
    ) {
        self.id = id
        self.accepts = accepts
        self.threshold = threshold
        self.heading = heading
        self.length = length
        self.captureRadius = captureRadius
        self.headingTolerance = headingTolerance
        self.anyHeading = anyHeading
    }

    public var direction: Vec2 { Vec2(heading: heading) }
    public var end: Vec2 { threshold + direction * length }

    public func accepts(_ kind: AircraftKind) -> Bool { accepts.contains(kind) }
}

/// Terrain that blocks every flight level up to and including `ceiling`.
public struct NoFlyZone: Identifiable, Sendable {
    public let id: String
    public let center: Vec2
    public let radius: Float
    public let ceiling: Int

    public init(id: String, center: Vec2, radius: Float, ceiling: Int) {
        self.id = id
        self.center = center
        self.radius = radius
        self.ceiling = ceiling
    }

    /// Whether an aircraft at this point and height flies into the terrain.
    public func blocks(_ point: Vec2, altitude: Float) -> Bool {
        point.distance(to: center) < radius && altitude < Float(ceiling) + 0.4
    }

    /// Whether the zone covers the runway's capture zone or landing roll.
    func overlaps(_ runway: Runway) -> Bool {
        if center.distance(to: runway.threshold) < radius + runway.captureRadius { return true }
        let roll = runway.end - runway.threshold
        let along =
            roll.lengthSquared > 0
            ? min(max((center - runway.threshold).dot(roll) / roll.lengthSquared, 0), 1) : 0
        return center.distance(to: runway.threshold + roll * along) < radius
    }
}

/// A side of the playfield that aircraft can arrive from.
public enum Edge: String, CaseIterable, Codable, Sendable {
    case north, east, south, west
}

// MARK: - Decoding

extension Level: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, field, flightLevels, runways, noFlyZones, spawnEdges, profiles
    }

    private struct Field: Decodable {
        let width: Float
        let height: Float
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let field = try container.decode(Field.self, forKey: .field)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            size: Vec2(field.width, field.height),
            flightLevels: try container.decodeIfPresent(Int.self, forKey: .flightLevels) ?? 1,
            runways: try container.decode([Runway].self, forKey: .runways),
            noFlyZones: try container.decodeIfPresent([NoFlyZone].self, forKey: .noFlyZones) ?? [],
            spawnEdges: try container.decodeIfPresent([Edge].self, forKey: .spawnEdges)
                ?? Edge.allCases,
            profiles: try container.decodeIfPresent([String].self, forKey: .profiles) ?? []
        )
    }
}

extension Runway: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, accepts, threshold, heading, length, captureRadius, headingTolerance, anyHeading
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let heading = try container.decodeIfPresent(Float.self, forKey: .heading) ?? 0
        let tolerance = try container.decodeIfPresent(Float.self, forKey: .headingTolerance) ?? 35
        self.init(
            id: try container.decode(String.self, forKey: .id),
            accepts: Set(try container.decode([AircraftKind].self, forKey: .accepts)),
            threshold: try container.decode(Vec2.self, forKey: .threshold),
            heading: Angles.radians(fromDegrees: heading),
            length: try container.decodeIfPresent(Float.self, forKey: .length) ?? 0,
            captureRadius: try container.decode(Float.self, forKey: .captureRadius),
            headingTolerance: Angles.radians(fromDegrees: tolerance),
            anyHeading: try container.decodeIfPresent(Bool.self, forKey: .anyHeading) ?? false
        )
    }
}

extension NoFlyZone: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, circle, ceiling
    }

    private struct Circle: Decodable {
        let center: Vec2
        let radius: Float
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let circle = try container.decode(Circle.self, forKey: .circle)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            center: circle.center,
            radius: circle.radius,
            ceiling: try container.decode(Int.self, forKey: .ceiling)
        )
    }
}
