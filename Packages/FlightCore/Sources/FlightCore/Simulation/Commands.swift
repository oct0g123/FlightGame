extension World {
    mutating func apply(_ command: Command, events: inout [GameEvent]) {
        switch command {
        case .startPath(let id, let point):
            guard let i = index(of: id), aircraft[i].isFlying else { return }
            var path = FlightPath(start: aircraft[i].position)
            path.append(raw: point, in: level)
            aircraft[i].path = path

        case .extendPath(let id, let points, let pickedLevel):
            guard let i = index(of: id), var path = aircraft[i].path, path.isDrawing else { return }
            if let pickedLevel {
                let clamped = min(max(pickedLevel, 1), level.ceiling(for: aircraft[i].kind))
                path.addLevelMark(clamped, currentLevel: aircraft[i].targetLevel)
            }
            for point in points {
                path.append(raw: point, in: level)
            }
            aircraft[i].path = path
            tryToCommit(i, events: &events)

        case .finishPath(let id):
            guard let i = index(of: id), var path = aircraft[i].path, path.isDrawing else { return }
            path.flush()
            path.finishDrawing()
            aircraft[i].path = path.points.count >= 2 ? path : nil
            tryToCommit(i, events: &events)

        case .setLevel(let id, let requested):
            guard let i = index(of: id), aircraft[i].isFlying,
                aircraft[i].path?.isCommitted != true
            else { return }
            let clamped = min(max(requested, 1), level.ceiling(for: aircraft[i].kind))
            guard clamped != aircraft[i].targetLevel else { return }
            aircraft[i].targetLevel = clamped
            events.append(.levelChanged(id, level: clamped))
        }
    }

    /// Locks the path onto a runway if it ends in a matching capture zone,
    /// lined up, with room to descend. Otherwise reports why not (once).
    mutating func tryToCommit(_ i: Int, events: inout [GameEvent]) {
        guard var path = aircraft[i].path, !path.isCommitted, path.points.count >= 2,
            let end = path.points.last
        else { return }
        let plane = aircraft[i]
        defer { aircraft[i].path = path }

        guard
            let runway = level.runways.first(where: {
                $0.threshold.distance(to: end) <= $0.captureRadius
            })
        else {
            path.lastRejection = nil
            return
        }
        guard runway.accepts(plane.kind) else {
            reject(&path, plane.id, at: end, .wrongRunway, events: &events)
            return
        }
        if !runway.anyHeading {
            guard let tail = path.tailDirection(length: 4),
                abs(Angles.delta(from: tail.heading, to: runway.heading)) <= runway.headingTolerance
            else { return }
        }

        let glide = Self.glideSegment(from: end, onto: runway)
        let levelAtEnd = path.levelAtEnd(startingFrom: plane.targetLevel)
        let descent = Float(levelAtEnd - 1) / plane.spec.climbRate * plane.speed
        let needed = descent + Simulation.finalGlide
        let available = path.remainingLength + glide.length
        guard available >= needed else {
            reject(&path, plane.id, at: end, .tooHigh, events: &events)
            return
        }

        for point in glide.points {
            path.extend(through: point)
        }
        path.end(at: runway.threshold)
        if levelAtEnd > 1 {
            // Descend as late as possible, keeping high traffic out of the lower levels.
            let steps = Int((needed / FlightPath.spacing).rounded(.up))
            let index = max(path.head, path.points.count - 1 - steps)
            path.levelMarks.removeAll { $0.index >= index }
            path.levelMarks.append(LevelMark(index: index, level: 1))
        }
        path.lock(onto: runway)
        events.append(.pathCommitted(plane.id, runway.id))
    }

    private func reject(
        _ path: inout FlightPath, _ id: AircraftID, at point: Vec2, _ reason: RejectReason,
        events: inout [GameEvent]
    ) {
        guard path.lastRejection != reason else { return }
        path.lastRejection = reason
        events.append(.pathRejected(id, at: point, reason: reason))
    }

    /// A curve from the end of the drawn path that meets the runway along its heading.
    static func glideSegment(from start: Vec2, onto runway: Runway) -> (
        points: [Vec2], length: Float
    ) {
        let target = runway.threshold
        let distance = start.distance(to: target)
        guard distance > FlightPath.spacing else { return ([], distance) }
        if runway.anyHeading { return ([], distance) }
        // Quadratic Bézier whose tangent at the threshold is the runway heading.
        let control = target - runway.direction * (distance * 0.5)
        let samples = Int(distance.rounded(.up)) * 2
        var points: [Vec2] = []
        var length: Float = 0
        var previous = start
        for step in 1..<samples {
            let t = Float(step) / Float(samples)
            let point = start * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + target * (t * t)
            length += previous.distance(to: point)
            previous = point
            points.append(point)
        }
        length += previous.distance(to: target)
        return (points, length)
    }
}
