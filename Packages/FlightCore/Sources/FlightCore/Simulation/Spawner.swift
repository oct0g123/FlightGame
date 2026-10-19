struct SpawnerState: Sendable {
    /// When the next arrival is due to appear (its warning shows `warningLead` earlier).
    var nextArrival: Float
    /// The next arrival's script draws, kept until it can be announced fairly.
    var upcoming: ScriptedArrival?
    var lastSpawnTime: Float = -.infinity
}

/// One arrival from the seeded script: the same for everyone with the same seed.
struct ScriptedArrival: Sendable {
    let kind: AircraftKind
    let level: Int
    var edge: Edge
    /// Position along the edge, 0–1.
    var offset: Float
    /// Where it heads: a point in the middle part of the field, as fractions of its size.
    var aim: Vec2
}

extension World {
    /// Seconds an arrival takes to fly in, used to project its course for fairness.
    static let fairnessHorizon: Float = 4
    /// Arrivals appear this far outside the field.
    static let entryDistance: Float = 5

    mutating func updateSpawner(events: inout [GameEvent]) {
        spawnDueArrivals(events: &events)
        announceNextArrival(events: &events)
    }

    private mutating func spawnDueArrivals(events: inout [GameEvent]) {
        let now = time
        var k = 0
        while k < pendingArrivals.count {
            let arrival = pendingArrivals[k]
            guard arrival.spawnTime <= now else {
                k += 1
                continue
            }
            // Something flew into the entry, or another just appeared: wait a moment.
            guard entryIsClear(arrival), now - spawner.lastSpawnTime >= 1 else {
                pendingArrivals[k].spawnTime = now + 0.5
                k += 1
                continue
            }
            pendingArrivals.remove(at: k)
            let id = AircraftID(nextID)
            nextID += 1
            let speed = arrival.kind.spec.speed * profile.speedScale.value(at: now)
            aircraft.append(
                Aircraft(
                    id: id, kind: arrival.kind, position: arrival.entry,
                    heading: arrival.heading, level: arrival.level, speed: speed))
            spawner.lastSpawnTime = now
            events.append(.spawned(id))
        }
    }

    private mutating func announceNextArrival(events: inout [GameEvent]) {
        let now = time
        let lead = profile.warningLead
        guard now + lead >= spawner.nextArrival else { return }

        let airborne = aircraft.count { $0.isFlying } + pendingArrivals.count
        guard airborne < Int(profile.maxAirborne.value(at: now)) else {
            spawner.nextArrival = now + lead + 0.5
            return
        }

        var arrival = spawner.upcoming ?? drawScriptedArrival(at: spawner.nextArrival)
        var fair = isFair(arrival)
        var attempts = 0
        while !fair && attempts < 6 {
            arrival.edge = level.spawnEdges[random.fairness.nextInt(below: level.spawnEdges.count)]
            arrival.offset = 0.15 + random.fairness.nextUnit() * 0.7
            arrival.aim = Vec2(random.fairness.nextUnit(), random.fairness.nextUnit())
            fair = isFair(arrival)
            attempts += 1
        }
        guard fair else {
            spawner.upcoming = arrival
            spawner.nextArrival = now + lead + 0.5
            return
        }

        let pending = makePending(arrival, spawnTime: now + lead)
        pendingArrivals.append(pending)
        events.append(.arrivalWarning(pending))
        spawner.upcoming = nil
        spawner.nextArrival =
            max(spawner.nextArrival, now + lead)
            + profile.spawnInterval.value(at: spawner.nextArrival)
    }

    /// Draws a fixed number of values from the schedule stream, so the script
    /// stays in step however the game goes.
    private mutating func drawScriptedArrival(at time: Float) -> ScriptedArrival {
        let kindRoll = random.schedule.nextUnit()
        let levelRoll = random.schedule.nextUnit()
        let edgeIndex = random.schedule.nextInt(below: level.spawnEdges.count)
        let offset = 0.15 + random.schedule.nextUnit() * 0.7
        let aim = Vec2(random.schedule.nextUnit(), random.schedule.nextUnit())

        let kind = pickKind(roll: kindRoll, at: time)
        let ceiling = level.ceiling(for: kind)
        var levels = (profile.arrivalLevels[kind] ?? [1]).filter { (1...ceiling).contains($0) }
        if levels.isEmpty { levels = [1] }
        let level = levels[min(Int(levelRoll * Float(levels.count)), levels.count - 1)]
        return ScriptedArrival(
            kind: kind, level: level, edge: self.level.spawnEdges[edgeIndex], offset: offset,
            aim: aim)
    }

    /// Picks a kind from the current mix, skipping kinds this map has nowhere to land.
    private func pickKind(roll: Float, at time: Float) -> AircraftKind {
        let landable = profile.weights(at: time).filter { entry in
            level.runways.contains { $0.accepts(entry.kind) }
        }
        let total = landable.reduce(0) { $0 + $1.weight }
        guard total > 0 else {
            return AircraftKind.allCases.first { kind in level.runways.contains { $0.accepts(kind) }
            }
                ?? .prop
        }
        var remaining = roll * total
        for entry in landable {
            remaining -= entry.weight
            if remaining < 0 { return entry.kind }
        }
        return landable[landable.count - 1].kind
    }

    private func makePending(_ arrival: ScriptedArrival, spawnTime: Float) -> PendingArrival {
        let entry = entryPoint(edge: arrival.edge, offset: arrival.offset)
        // Aim somewhere in the middle 60% of the field.
        let target =
            level.center
            + Vec2(
                (arrival.aim.x - 0.5) * level.size.x * 0.6,
                (arrival.aim.y - 0.5) * level.size.y * 0.6)
        return PendingArrival(
            kind: arrival.kind, level: arrival.level, edge: arrival.edge, entry: entry,
            heading: (target - entry).heading, spawnTime: spawnTime)
    }

    private func entryPoint(edge: Edge, offset: Float) -> Vec2 {
        let size = level.size
        let outside = Self.entryDistance
        switch edge {
        case .north: return Vec2(size.x * offset, size.y + outside)
        case .south: return Vec2(size.x * offset, -outside)
        case .east: return Vec2(size.x + outside, size.y * offset)
        case .west: return Vec2(-outside, size.y * offset)
        }
    }

    /// Whether the arrival's first few seconds would stay clear of current traffic
    /// at its level, and away from other recent arrivals.
    private func isFair(_ arrival: ScriptedArrival) -> Bool {
        let pending = makePending(arrival, spawnTime: time + profile.warningLead)
        if pendingArrivals.contains(where: { $0.entry.distance(to: pending.entry) < 25 }) {
            return false
        }
        let speed = arrival.kind.spec.speed * profile.speedScale.value(at: time)
        let lead = profile.warningLead
        var t: Float = 0
        while t <= Self.fairnessHorizon {
            let newcomer = pending.entry + Vec2(heading: pending.heading) * (speed * t)
            for plane in aircraft where plane.isFlying {
                guard
                    abs(Float(plane.targetLevel) - Float(arrival.level))
                        < Simulation.verticalSeparation
                else { continue }
                let safe = Simulation.warningDistance(plane.kind, arrival.kind) * 2
                if plane.projectedPosition(after: lead + t).distance(to: newcomer) < safe {
                    return false
                }
            }
            t += 0.25
        }
        return true
    }

    /// Whether the entry point is free of traffic right now.
    private func entryIsClear(_ arrival: PendingArrival) -> Bool {
        !aircraft.contains { plane in
            plane.isFlying
                && abs(plane.altitude - Float(arrival.level)) < Simulation.verticalSeparation
                && plane.position.distance(to: arrival.entry)
                    < Simulation.warningDistance(plane.kind, arrival.kind) * 2
        }
    }
}

extension Aircraft {
    /// Where the aircraft will roughly be after `seconds`: along its path if it
    /// has one, otherwise straight ahead.
    func projectedPosition(after seconds: Float) -> Vec2 {
        let distance = speed * seconds
        if let path {
            let steps = Int(distance / FlightPath.spacing)
            if path.head + steps < path.points.count { return path.points[path.head + steps] }
            if let last = path.points.last {
                let beyond = distance - path.remainingLength
                return last + Vec2(heading: heading) * max(beyond, 0)
            }
        }
        return position + Vec2(heading: heading) * distance
    }
}
