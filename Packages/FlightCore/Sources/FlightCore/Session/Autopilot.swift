/// A simple bot that lands traffic. Used for the attract mode behind the menus,
/// soak tests and balancing. It issues the same commands a player would.
///
/// It's deliberately naive: it brings each aircraft down to level 1 and flies
/// it straight to an approach point and onto its runway, without avoiding
/// other traffic.
public struct Autopilot: Sendable {
    /// Seconds before the bot routes a new aircraft, like a player's reaction time.
    public var reactionTime: Float
    /// How far before the threshold the final approach starts, in field units.
    public var approachDistance: Float = 14

    private var firstSeen: [AircraftID: Float] = [:]
    private var lastRouted: [AircraftID: Float] = [:]

    public init(reactionTime: Float = 1) {
        self.reactionTime = reactionTime
    }

    public mutating func commands(for world: World) -> [Command] {
        let now = world.time
        var commands: [Command] = []
        let present = Set(world.aircraft.map(\.id))
        firstSeen = firstSeen.filter { present.contains($0.key) }
        lastRouted = lastRouted.filter { present.contains($0.key) }

        for plane in world.aircraft where plane.isFlying {
            let seen = firstSeen[plane.id] ?? now
            firstSeen[plane.id] = seen
            guard now - seen >= reactionTime else { continue }

            if plane.targetLevel > 1 && plane.path?.isCommitted != true {
                commands.append(.setLevel(plane.id, 1))
            }
            let routedRecently = lastRouted[plane.id].map { now - $0 < 2 } ?? false
            guard plane.path == nil, !routedRecently,
                let runway = nearestRunway(for: plane, in: world.level)
            else { continue }
            commands += route(plane, to: runway, in: world.level)
            lastRouted[plane.id] = now
        }
        return commands
    }

    private func nearestRunway(for plane: Aircraft, in level: Level) -> Runway? {
        level.runways
            .filter { $0.accepts(plane.kind) }
            .min {
                $0.threshold.distance(to: plane.position)
                    < $1.threshold.distance(to: plane.position)
            }
    }

    private func route(_ plane: Aircraft, to runway: Runway, in level: Level) -> [Command] {
        var waypoints: [Vec2] = []
        if !runway.anyHeading {
            waypoints.append(
                level.clamp(runway.threshold - runway.direction * approachDistance, inset: 3))
        }
        waypoints.append(runway.threshold)

        var points: [Vec2] = []
        var from = plane.position
        for waypoint in waypoints {
            let steps = max(Int((from.distance(to: waypoint) / 2).rounded(.up)), 1)
            for step in 1...steps {
                points.append(from.lerp(to: waypoint, Float(step) / Float(steps)))
            }
            from = waypoint
        }
        let start = plane.position + Vec2(heading: plane.heading)
        return [
            .startPath(plane.id, at: start),
            .extendPath(plane.id, points: points, level: nil),
            .finishPath(plane.id),
        ]
    }
}
