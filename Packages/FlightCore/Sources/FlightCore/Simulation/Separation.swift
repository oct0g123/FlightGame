extension World {
    /// Updates conflict warnings and detects crashes between aircraft and into terrain.
    mutating func checkSeparation(events: inout [GameEvent]) {
        let flying = aircraft.indices.filter { aircraft[$0].isFlying }
        var current = Set<AircraftPair>()
        var crashes: [Crash] = []

        for (n, i) in flying.enumerated() {
            for j in flying[(n + 1)...] {
                let a = aircraft[i]
                let b = aircraft[j]
                let distance = a.position.distance(to: b.position)
                let heightGap = abs(a.altitude - b.altitude)
                let pair = AircraftPair(a.id, b.id)
                if heightGap < Simulation.verticalSeparation
                    && distance < a.spec.radius + b.spec.radius
                {
                    crashes.append(.midair(pair, at: a.position.lerp(to: b.position, 0.5)))
                }
                let warning = Simulation.warningDistance(a.kind, b.kind)
                // Hysteresis: a conflict ends a little further out than it starts.
                let inConflict =
                    conflicts.contains(pair)
                    ? distance < warning * 1.1 && heightGap < Simulation.verticalSeparation + 0.1
                    : distance < warning && heightGap < Simulation.verticalSeparation
                if inConflict { current.insert(pair) }
            }
        }

        for i in flying {
            let plane = aircraft[i]
            if level.noFlyZones.contains(where: {
                $0.blocks(plane.position, altitude: plane.altitude)
            }) {
                crashes.append(.terrain(plane.id, at: plane.position))
            }
        }

        for pair in current.subtracting(conflicts).sorted() {
            events.append(.conflictBegan(pair))
        }
        for pair in conflicts.subtracting(current).sorted() {
            events.append(.conflictEnded(pair))
        }
        conflicts = current

        resolve(crashes, events: &events)
    }

    /// Each crash costs a strike. The last strike ends the game and leaves the
    /// wreck in place; earlier ones remove the aircraft involved.
    private mutating func resolve(_ crashes: [Crash], events: inout [GameEvent]) {
        var involved = Set<AircraftID>()
        for crash in crashes {
            // An aircraft can only crash once per tick.
            guard involved.isDisjoint(with: crash.aircraft) else { continue }
            involved.formUnion(crash.aircraft)
            events.append(.crashed(crash))
            strikesLeft -= 1
            if strikesLeft <= 0 {
                phase = .over(crash)
                events.append(.gameOver(crash))
                return
            }
            for id in crash.aircraft {
                remove(id, events: &events)
            }
        }
    }
}
