extension World {
    /// Flies or rolls every aircraft one tick, and removes those that finished landing.
    mutating func moveAircraft(events: inout [GameEvent]) {
        let level = self.level
        var finished: [AircraftID] = []
        for i in aircraft.indices {
            aircraft[i].rememberPreviousTick()
            switch aircraft[i].state {
            case .flying:
                aircraft[i].fly(in: level, events: &events)
                // The landing counts at touchdown; the roll-out is just for show.
                if !aircraft[i].isFlying { landed += 1 }
            case .landing(let runwayID, _):
                guard let runway = level.runway(runwayID) else { continue }
                if aircraft[i].roll(on: runway) {
                    finished.append(aircraft[i].id)
                }
            }
        }
        for id in finished {
            remove(id, events: &events)
            events.append(.landed(id))
        }
    }

    /// Removes an aircraft, ending any conflicts it was part of.
    mutating func remove(_ id: AircraftID, events: inout [GameEvent]) {
        aircraft.removeAll { $0.id == id }
        for pair in conflicts.filter({ $0.contains(id) }).sorted() {
            conflicts.remove(pair)
            events.append(.conflictEnded(pair))
        }
    }
}

extension Aircraft {
    /// One tick of flight: steer along the path (or straight, or back into the
    /// field), turn within the kind's limits, move, then climb or descend.
    mutating func fly(in level: Level, events: inout [GameEvent]) {
        let dt = Simulation.dt
        var desiredHeading = heading
        var glideRemaining: Float?

        if var path {
            path.advance(from: position)
            for mark in path.takeReachedMarks() {
                let clamped = min(max(mark.level, 1), level.ceiling(for: kind))
                if clamped != targetLevel {
                    targetLevel = clamped
                    events.append(.levelChanged(id, level: clamped))
                }
            }
            if path.isFinished(at: position) {
                if let runwayID = path.committedRunway, let runway = level.runway(runwayID) {
                    touchDown(on: runway)
                    events.append(.touchedDown(id, runwayID))
                    return
                }
                // Caught up with the finger: hold course until more path arrives.
                self.path = path.isDrawing ? path : nil
            } else {
                let target = path.lookahead(max(2, speed * 0.35))
                desiredHeading = (target - position).heading
                if path.isCommitted && path.remainingLength <= Simulation.finalGlide {
                    glideRemaining = path.remainingLength
                }
                self.path = path
            }
        } else if hasEnteredField {
            // Heading out of the field: turn back toward the middle.
            let ahead = position + Vec2(heading: heading) * (speed * 0.8)
            if !level.contains(ahead, inset: 2) {
                desiredHeading = (level.center - position).heading
            }
        }

        turn(toward: desiredHeading, dt: dt)
        position += Vec2(heading: heading) * (speed * dt)
        if !hasEnteredField && level.contains(position) { hasEnteredField = true }
        updateAltitude(glideRemaining: glideRemaining, dt: dt)
    }

    mutating func turn(toward desired: Float, dt: Float) {
        let limit = spec.maxTurnRate * dt
        let step = min(max(Angles.delta(from: heading, to: desired), -limit), limit)
        heading = Angles.wrap(heading + step)
        turnRate = step / dt
    }

    private mutating func updateAltitude(glideRemaining: Float?, dt: Float) {
        let rate = spec.climbRate * dt
        if let glideRemaining {
            // Final glide: down to the ground by the threshold.
            let target = max(glideRemaining / Simulation.finalGlide, 0)
            if altitude > target { altitude = max(target, altitude - max(rate, 2 * dt)) }
            return
        }
        let target = Float(targetLevel)
        if altitude < target {
            altitude = min(target, altitude + rate)
        } else if altitude > target {
            altitude = max(target, altitude - rate)
        }
    }
}
