/// A touch, click or pinch, already converted to field units by the platform layer.
public struct PointerEvent: Sendable {
    public enum Phase: Sendable {
        case began, moved, ended, cancelled
    }

    /// Stable for one touch from began to ended, so several fingers can draw at once.
    public let id: Int
    public let phase: Phase
    public let location: Vec2
    /// visionOS only: hand height relative to where the pinch began, in level units.
    public let height: Float?

    public init(id: Int, phase: Phase, location: Vec2, height: Float? = nil) {
        self.id = id
        self.phase = phase
        self.location = location
        self.height = height
    }
}

/// What a pointer event led to.
public enum DrawingOutput: Equatable, Sendable {
    case command(Command)
    /// A tap on an aircraft, without dragging: show its ▲/▼ level controls.
    case tapped(AircraftID)
}

/// Turns pointer events into commands. Knows nothing about any platform.
///
/// A touch grabs the nearest aircraft within `grabRadius`. Dragging past
/// `tapSlop` starts a path; releasing before then counts as a tap, so tapping
/// never wipes out an aircraft's existing path.
public struct PathDrawingController: Sendable {
    /// How far from a touch an aircraft can be grabbed, in field units.
    public var grabRadius: Float
    /// Movement below this, in field units, is still a tap.
    public var tapSlop: Float
    /// Extra height, in levels, needed to switch level, so it doesn't flicker at a boundary.
    public var levelHysteresis: Float = 0.15

    private var pointers: [Int: Binding] = [:]

    private struct Binding: Sendable {
        let aircraft: AircraftID
        let start: Vec2
        let startLevel: Int
        var level: Int
        var isDragging = false
    }

    public init(grabRadius: Float = 8, tapSlop: Float = 1.5) {
        self.grabRadius = grabRadius
        self.tapSlop = tapSlop
    }

    /// The aircraft each active pointer is holding.
    public var heldAircraft: Set<AircraftID> { Set(pointers.values.map(\.aircraft)) }

    public mutating func handle(_ event: PointerEvent, in world: World) -> [DrawingOutput] {
        switch event.phase {
        case .began:
            if let plane = grab(at: event.location, in: world) {
                pointers[event.id] = Binding(
                    aircraft: plane.id, start: event.location, startLevel: plane.targetLevel,
                    level: plane.targetLevel)
            }
            return []

        case .moved:
            guard var binding = pointers[event.id] else { return [] }
            guard let plane = world.aircraft(binding.aircraft), plane.isFlying else {
                pointers[event.id] = nil
                return []
            }
            var outputs: [DrawingOutput] = []
            if !binding.isDragging {
                guard event.location.distance(to: binding.start) > tapSlop else { return [] }
                binding.isDragging = true
                outputs.append(.command(.startPath(binding.aircraft, at: binding.start)))
            }
            var level: Int?
            if let height = event.height {
                binding.level = updatedLevel(
                    binding, height: height, ceiling: world.level.ceiling(for: plane.kind))
                level = binding.level
            }
            outputs.append(
                .command(.extendPath(binding.aircraft, points: [event.location], level: level)))
            pointers[event.id] = binding
            return outputs

        case .ended, .cancelled:
            guard let binding = pointers.removeValue(forKey: event.id) else { return [] }
            if binding.isDragging { return [.command(.finishPath(binding.aircraft))] }
            return event.phase == .ended ? [.tapped(binding.aircraft)] : []
        }
    }

    /// The nearest flying aircraft within reach that no other pointer is holding.
    private func grab(at location: Vec2, in world: World) -> Aircraft? {
        let held = heldAircraft
        return world.aircraft
            .filter { $0.isFlying && !held.contains($0.id) }
            .map { (plane: $0, distance: $0.position.distance(to: location)) }
            .filter { $0.distance <= grabRadius }
            .min { $0.distance < $1.distance }?
            .plane
    }

    private func updatedLevel(_ binding: Binding, height: Float, ceiling: Int) -> Int {
        let wanted = Float(binding.startLevel) + height
        var level = binding.level
        while wanted > Float(level) + 0.5 + levelHysteresis && level < ceiling { level += 1 }
        while wanted < Float(level) - 0.5 - levelHysteresis && level > 1 { level -= 1 }
        return level
    }
}
