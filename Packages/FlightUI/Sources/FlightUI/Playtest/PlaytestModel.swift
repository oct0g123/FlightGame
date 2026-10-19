import FlightCore
import Foundation
import Observation

/// State for the Phase 1 playtest screen: the running game, input, and
/// short-lived feedback like rejection flashes.
@Observable
final class PlaytestModel {
    static let levels: [Level] = (try? BuiltInContent.levels()) ?? []
    static let profiles: [(id: String, name: String)] = [
        ("classic", "Classic"), ("relaxed", "Relaxed"),
    ]

    private(set) var session: GameSession
    private(set) var levelID: String
    private(set) var profileID: String
    /// The aircraft whose ▲/▼ controls are open.
    private(set) var levelControls: LevelControls?
    private(set) var flashes: [Flash] = []
    private(set) var held: Set<AircraftID> = []
    var autopilotIsOn = false
    var isShowing3D = false

    @ObservationIgnored private var controller = PathDrawingController()
    @ObservationIgnored private var autopilot = Autopilot()
    @ObservationIgnored private var lastFrame: Date?
    @ObservationIgnored private var pointerIDs: [AnyHashable: Int] = [:]
    @ObservationIgnored private var nextPointerID = 1

    struct LevelControls: Equatable {
        let aircraft: AircraftID
        var openedAt: Float
    }

    struct Flash: Identifiable, Equatable {
        static let lifetime: Double = 0.9

        enum Kind: Equatable {
            case committed(AircraftKind)
            case rejected(RejectReason)
        }

        let id: Int
        let point: Vec2
        let kind: Kind
        let time: Float
    }

    init() {
        // Locals, because @Observable properties can't be read until every one is set.
        let levelID = BuiltInContent.levelIDs[0]
        let profileID = Self.profiles[0].id
        self.levelID = levelID
        self.profileID = profileID
        session = Self.makeSession(levelID: levelID, profileID: profileID)
    }

    /// The clock stops while paused or after a crash.
    var isFrozen: Bool { session.isPaused || session.hud.isOver }

    var levelName: String { session.world.level.name }

    // MARK: - Game control

    func select(level id: String) {
        guard id != levelID else { return }
        levelID = id
        restart()
    }

    func select(profile id: String) {
        guard id != profileID else { return }
        profileID = id
        restart()
    }

    func restart() {
        session = Self.makeSession(levelID: levelID, profileID: profileID)
        controller = PathDrawingController()
        autopilot = Autopilot()
        pointerIDs.removeAll()
        levelControls = nil
        flashes.removeAll()
        held.removeAll()
        lastFrame = nil
    }

    func togglePause() {
        session.isPaused.toggle()
        lastFrame = nil
    }

    /// Advances the game to `date`. Called once per display frame.
    func frame(at date: Date) {
        let seconds = lastFrame.map { date.timeIntervalSince($0) } ?? 0
        lastFrame = date
        if autopilotIsOn { session.send(autopilot.commands(for: session.world)) }
        session.advance(by: seconds)
        collectFlashes()

        let world = session.world
        if let controls = levelControls,
            world.time - controls.openedAt > 2.5
                || world.aircraft(controls.aircraft)?.isFlying != true
        {
            levelControls = nil
        }
        let nowHeld = controller.heldAircraft
        if nowHeld != held { held = nowHeld }
    }

    // MARK: - Input

    enum PointerPhase {
        case active, ended, cancelled
    }

    /// Handles one touch or mouse update. `key` identifies the touch across updates.
    func pointer(
        _ key: AnyHashable, phase: PointerPhase, at location: CGPoint, transform: FieldTransform
    ) {
        let isNew = pointerIDs[key] == nil
        if isNew {
            guard phase == .active else { return }
            pointerIDs[key] = nextPointerID
            nextPointerID += 1
        }
        guard let id = pointerIDs[key] else { return }
        let eventPhase: PointerEvent.Phase =
            switch phase {
            case .active: isNew ? .began : .moved
            case .ended: .ended
            case .cancelled: .cancelled
            }
        if phase != .active { pointerIDs[key] = nil }

        // About 36 points of reach whatever the screen size.
        controller.grabRadius = transform.units(36)
        controller.tapSlop = transform.units(8)
        let event = PointerEvent(id: id, phase: eventPhase, location: transform.field(location))
        for output in controller.handle(event, in: session.world) {
            switch output {
            case .command(let command):
                session.send(command)
            case .tapped(let aircraft):
                if session.world.level.flightLevels > 1 {
                    levelControls = LevelControls(aircraft: aircraft, openedAt: session.world.time)
                }
            }
        }
        held = controller.heldAircraft
    }

    func changeLevel(of id: AircraftID, by delta: Int) {
        guard let plane = session.world.aircraft(id) else { return }
        session.send(.setLevel(id, plane.targetLevel + delta))
        if levelControls?.aircraft == id { levelControls?.openedAt = session.world.time }
    }

    /// The aircraft nearest a hover point, for keyboard level changes on the Mac.
    func aircraft(near location: CGPoint, transform: FieldTransform) -> AircraftID? {
        let point = transform.field(location)
        let reach = transform.units(36)
        return session.world.aircraft
            .filter { $0.isFlying && $0.position.distance(to: point) <= reach }
            .min { $0.position.distance(to: point) < $1.position.distance(to: point) }?
            .id
    }

    // MARK: - Private

    private func collectFlashes() {
        let now = session.world.time
        var updated = flashes.filter { Double(now - $0.time) < Flash.lifetime }
        for event in session.frameEvents {
            switch event {
            case .pathCommitted(_, let runwayID):
                if let runway = session.world.level.runway(runwayID) {
                    updated.append(
                        Flash(
                            id: nextFlashID(), point: runway.threshold,
                            kind: .committed(runway.kind), time: now))
                }
            case .pathRejected(_, let point, let reason):
                updated.append(
                    Flash(id: nextFlashID(), point: point, kind: .rejected(reason), time: now))
            default:
                break
            }
        }
        if updated != flashes { flashes = updated }
    }

    @ObservationIgnored private var flashCounter = 0

    private func nextFlashID() -> Int {
        flashCounter += 1
        return flashCounter
    }

    private static func makeSession(levelID: String, profileID: String) -> GameSession {
        // Bundled content is validated by FlightCore's tests, so a failure here is a build problem.
        guard let level = try? BuiltInContent.level(levelID),
            let profile = try? BuiltInContent.profile(profileID)
        else { preconditionFailure("Missing bundled content: \(levelID) / \(profileID)") }
        return GameSession(level: level, profile: profile, seed: UInt64.random(in: 1...UInt64.max))
    }
}
