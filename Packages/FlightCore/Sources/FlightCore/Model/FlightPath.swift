/// "Change to `level` when the aircraft reaches point `index`."
public struct LevelMark: Equatable, Sendable {
    public let index: Int
    public let level: Int
}

/// A path the player drew, resampled to evenly spaced points.
public struct FlightPath: Sendable {
    /// Distance between consecutive points, in field units.
    public static let spacing: Float = 1
    /// Most points a path can hold. Points already flown are dropped as it goes.
    public static let capacity = 2000

    public internal(set) var points: [Vec2]
    /// First point the aircraft hasn't reached yet.
    public internal(set) var head = 0
    /// Upcoming level changes, in index order.
    public internal(set) var levelMarks: [LevelMark] = []
    /// Set once the path locks onto a runway.
    public internal(set) var committedRunway: RunwayID?
    /// True while the player's finger is still down.
    public internal(set) var isDrawing = true

    // Input smoothing state.
    private var smoothed: Vec2
    private var lastRaw: Vec2
    /// The last rejection reported, so each one is only announced once.
    var lastRejection: RejectReason?

    init(start: Vec2) {
        points = [start]
        smoothed = start
        lastRaw = start
    }

    public var isCommitted: Bool { committedRunway != nil }

    /// Length still to fly, from the head to the end.
    public var remainingLength: Float { Float(max(points.count - 1 - head, 0)) * Self.spacing }

    /// Adds a raw input point: clamps it inside the field, smooths out jitter,
    /// and emits evenly spaced points toward it.
    mutating func append(raw: Vec2, in level: Level) {
        let point = level.clamp(raw, inset: 1)
        guard point.distance(to: lastRaw) >= 0.5 else { return }
        lastRaw = point
        smoothed = smoothed.lerp(to: point, 0.6)
        resample(toward: smoothed)
    }

    /// Catches the path up with the last raw point when the finger lifts.
    mutating func flush() {
        resample(toward: lastRaw)
        if let last = points.last, last.distance(to: lastRaw) > 0.3, points.count < Self.capacity {
            points.append(lastRaw)
        }
    }

    /// Extends the path toward `target` without smoothing. Used for generated segments.
    mutating func extend(through target: Vec2) {
        resample(toward: target)
        smoothed = target
        lastRaw = target
    }

    /// Extends the path so it ends exactly at `target`.
    mutating func end(at target: Vec2) {
        extend(through: target)
        if let last = points.last, last.distance(to: target) > 0.01, points.count < Self.capacity {
            points.append(target)
        }
    }

    private mutating func resample(toward target: Vec2) {
        guard var cursor = points.last else { return }
        while cursor.distance(to: target) >= Self.spacing, points.count < Self.capacity {
            cursor = cursor + (target - cursor).normalized * Self.spacing
            points.append(cursor)
        }
    }

    /// Moves the head to the closest point near the aircraft. Never moves backward.
    mutating func advance(from position: Vec2) {
        let window = head..<min(head + 12, points.count)
        guard
            let nearest = window.min(by: {
                points[$0].distance(to: position) < points[$1].distance(to: position)
            })
        else { return }
        head = max(head, nearest)
        // Points behind the aircraft are no longer needed.
        if head > 256 { dropFlownPoints() }
    }

    /// The point `distance` ahead of the head, or the end of the path.
    func lookahead(_ distance: Float) -> Vec2 {
        let steps = Int((distance / Self.spacing).rounded(.up))
        return points[min(head + steps, points.count - 1)]
    }

    /// Whether the aircraft has reached the end of the path.
    func isFinished(at position: Vec2) -> Bool {
        guard let last = points.last else { return true }
        return head >= points.count - 1 || position.distance(to: last) < 1
    }

    /// Direction of the last `length` units of the path, if it's that long.
    func tailDirection(length: Float) -> Vec2? {
        let steps = Int(length / Self.spacing)
        guard points.count > steps, let last = points.last else { return nil }
        return (last - points[points.count - 1 - steps]).normalized
    }

    /// The level the aircraft will be heading for at the end of the path.
    func levelAtEnd(startingFrom level: Int) -> Int { levelMarks.last?.level ?? level }

    mutating func addLevelMark(_ level: Int, currentLevel: Int) {
        guard level != levelAtEnd(startingFrom: currentLevel) else { return }
        let index = points.count - 1
        levelMarks.removeAll { $0.index >= index }
        levelMarks.append(LevelMark(index: index, level: level))
    }

    /// Removes and returns the marks the head has reached.
    mutating func takeReachedMarks() -> [LevelMark] {
        let reached = levelMarks.prefix { $0.index <= head }
        levelMarks.removeFirst(reached.count)
        return Array(reached)
    }

    mutating func lock(onto runway: Runway) {
        committedRunway = runway.id
        isDrawing = false
        lastRejection = nil
    }

    mutating func finishDrawing() { isDrawing = false }

    private mutating func dropFlownPoints() {
        let dropped = head
        points.removeFirst(dropped)
        head = 0
        levelMarks = levelMarks.map { LevelMark(index: $0.index - dropped, level: $0.level) }
    }
}
