import FlightCore
import SwiftUI

/// Draws the simulation with flat shapes: the Phase 1 "fun with circles" view.
struct FieldRenderer {
    let world: World
    /// Interpolation between the last tick and the next, for smooth motion.
    let alpha: Float
    let transform: FieldTransform
    let held: Set<AircraftID>
    let flashes: [PlaytestModel.Flash]

    private var isMultiLevel: Bool { world.level.flightLevels > 1 }

    func draw(in context: inout GraphicsContext) {
        context.fill(
            Path(roundedRect: transform.rect, cornerRadius: 8), with: .color(Palette.grass))
        for zone in world.level.noFlyZones { drawZone(zone, in: &context) }
        for runway in world.level.runways { drawRunway(runway, in: &context) }
        for arrival in world.pendingArrivals { drawArrival(arrival, in: &context) }
        for plane in world.aircraft { drawPath(of: plane, in: &context) }
        drawConflicts(in: &context)
        for plane in world.aircraft { drawAircraft(plane, in: &context) }
        for flash in flashes { drawFlash(flash, in: &context) }
        if case .over(let crash) = world.phase { drawCrash(at: crash.location, in: &context) }
    }

    // MARK: - Map

    private func drawZone(_ zone: NoFlyZone, in context: inout GraphicsContext) {
        let circle = circlePath(zone.center, radius: zone.radius)
        context.fill(circle, with: .color(Palette.terrain.opacity(0.45)))
        context.stroke(circle, with: .color(Palette.terrain), lineWidth: 1.5)
        label(
            "⛰ clear above \(zone.ceiling)", at: transform.point(zone.center), size: 10,
            in: &context)
    }

    private func drawRunway(_ runway: Runway, in context: inout GraphicsContext) {
        let color = runway.kind.color
        let capture = circlePath(runway.threshold, radius: runway.captureRadius)
        context.stroke(
            capture, with: .color(color.opacity(0.6)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        if runway.anyHeading {
            let pad = circlePath(runway.threshold, radius: 3.5)
            context.fill(pad, with: .color(Palette.tarmac))
            context.stroke(pad, with: .color(color), lineWidth: 2)
            label("H", at: transform.point(runway.threshold), size: 12, in: &context)
            return
        }
        let side = Vec2(-runway.direction.y, runway.direction.x) * 1.8
        var strip = Path()
        strip.addLines([
            transform.point(runway.threshold + side), transform.point(runway.end + side),
            transform.point(runway.end - side), transform.point(runway.threshold - side),
        ])
        strip.closeSubpath()
        context.fill(strip, with: .color(Palette.tarmac))
        // Coloured threshold bar and glyph where aircraft touch down.
        var bar = Path()
        bar.move(to: transform.point(runway.threshold + side))
        bar.addLine(to: transform.point(runway.threshold - side))
        context.stroke(bar, with: .color(color), lineWidth: 4)
        let glyphPoint = transform.point(runway.threshold - runway.direction * 4)
        label(runway.kind.glyph, at: glyphPoint, size: 13, color: color, in: &context)
    }

    private func drawArrival(_ arrival: PendingArrival, in context: inout GraphicsContext) {
        let blink = 0.55 + 0.45 * sin(Double(world.time) * 9)
        let point = transform.point(world.level.clamp(arrival.entry, inset: 3))
        var arrow = context
        arrow.opacity = blink
        arrow.translateBy(x: point.x, y: point.y)
        arrow.rotate(by: .radians(Double(-arrival.heading)))
        let size = transform.length(3)
        var triangle = Path()
        triangle.addLines([
            CGPoint(x: size, y: 0), CGPoint(x: -size * 0.7, y: size * 0.75),
            CGPoint(x: -size * 0.7, y: -size * 0.75),
        ])
        triangle.closeSubpath()
        arrow.fill(triangle, with: .color(arrival.kind.color))
        arrow.stroke(triangle, with: .color(.white), lineWidth: 1.5)
        if isMultiLevel {
            label(
                "\(arrival.level)", at: CGPoint(x: point.x, y: point.y - size * 1.6), size: 11,
                in: &context)
        }
    }

    // MARK: - Traffic

    private func drawPath(of plane: Aircraft, in context: inout GraphicsContext) {
        guard let path = plane.path, path.head < path.points.count else { return }
        var line = Path()
        line.move(to: transform.point(plane.position(interpolatedBy: alpha)))
        for point in path.points[path.head...] {
            line.addLine(to: transform.point(point))
        }
        if let runwayID = path.committedRunway, let runway = world.level.runway(runwayID) {
            context.stroke(
                line, with: .color(runway.kind.color),
                style: StrokeStyle(lineWidth: 3, lineCap: .round))
        } else {
            context.stroke(
                line, with: .color(.white.opacity(0.9)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5]))
        }
        for mark in path.levelMarks where mark.index < path.points.count {
            let point = transform.point(path.points[mark.index])
            context.fill(circlePath(point, radius: 7), with: .color(.white))
            label("\(mark.level)", at: point, size: 10, color: .black, in: &context)
        }
    }

    private func drawConflicts(in context: inout GraphicsContext) {
        let pulse = 0.6 + 0.4 * sin(Double(world.time) * 14)
        for pair in world.conflicts {
            for id in [pair.first, pair.second] {
                guard let plane = world.aircraft(id) else { continue }
                let radius = Simulation.warningDistance(plane.kind, plane.kind) / 2
                let ring = circlePath(
                    transform.point(plane.position(interpolatedBy: alpha)),
                    radius: transform.length(radius))
                context.stroke(ring, with: .color(Palette.warning.opacity(pulse)), lineWidth: 2.5)
            }
        }
    }

    private func drawAircraft(_ plane: Aircraft, in context: inout GraphicsContext) {
        let position = plane.position(interpolatedBy: alpha)
        let point = transform.point(position)
        let radius = transform.length(plane.spec.radius)
        let altitude = plane.altitude(interpolatedBy: alpha)

        var body = context
        if case .landing(_, let elapsed) = plane.state {
            body.opacity = max(0.25, 1 - Double(elapsed) / 4)
        }
        if isMultiLevel && altitude > 0.05 {
            // A shadow that drifts further away the higher the aircraft flies.
            let shadow = transform.point(position + Vec2(1, -1) * (altitude * 1.2))
            body.fill(circlePath(shadow, radius: radius * 0.7), with: .color(.black.opacity(0.18)))
        }
        body.stroke(
            circlePath(point, radius: radius), with: .color(.white.opacity(0.3)), lineWidth: 1)
        if held.contains(plane.id) {
            body.stroke(circlePath(point, radius: radius + 4), with: .color(.white), lineWidth: 3)
        }

        var shape = body
        shape.translateBy(x: point.x, y: point.y)
        shape.rotate(by: .radians(Double(-plane.heading(interpolatedBy: alpha))))
        var arrow = Path()
        arrow.addLines([
            CGPoint(x: radius * 1.15, y: 0), CGPoint(x: -radius * 0.8, y: radius * 0.85),
            CGPoint(x: -radius * 0.35, y: 0), CGPoint(x: -radius * 0.8, y: -radius * 0.85),
        ])
        arrow.closeSubpath()
        shape.fill(arrow, with: .color(plane.kind.color))
        shape.stroke(arrow, with: .color(.white), lineWidth: 1.5)

        if isMultiLevel && plane.isFlying {
            let trend =
                Float(plane.targetLevel) > altitude + 0.05
                ? "↑" : Float(plane.targetLevel) < altitude - 0.05 ? "↓" : ""
            let tag = CGPoint(x: point.x + radius + 9, y: point.y - radius - 4)
            label("\(plane.targetLevel)\(trend)", at: tag, size: 12, in: &body)
        }
    }

    private func drawFlash(_ flash: PlaytestModel.Flash, in context: inout GraphicsContext) {
        let age = Double(world.time - flash.time)
        let fade = max(0, 1 - age / PlaytestModel.Flash.lifetime)
        let point = transform.point(flash.point)
        var faded = context
        faded.opacity = fade
        switch flash.kind {
        case .committed(let kind):
            let ring = circlePath(point, radius: transform.length(4 + Float(age) * 10))
            faded.stroke(ring, with: .color(kind.color), lineWidth: 3)
        case .rejected(let reason):
            let color = reason == .tooHigh ? Palette.caution : Palette.warning
            faded.fill(circlePath(point, radius: 6), with: .color(color))
            let text = reason == .tooHigh ? "too high" : "wrong runway"
            label(
                text, at: CGPoint(x: point.x, y: point.y - 14), size: 11, color: color, in: &faded)
        }
    }

    private func drawCrash(at location: Vec2, in context: inout GraphicsContext) {
        let point = transform.point(location)
        context.fill(
            circlePath(point, radius: transform.length(5)),
            with: .color(Palette.warning.opacity(0.35)))
        label("✕", at: point, size: 26, color: Palette.warning, in: &context)
    }

    // MARK: - Helpers

    private func circlePath(_ center: Vec2, radius: Float) -> Path {
        circlePath(transform.point(center), radius: transform.length(radius))
    }

    private func circlePath(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func label(
        _ text: String, at point: CGPoint, size: CGFloat, color: Color = .white,
        in context: inout GraphicsContext
    ) {
        context.draw(
            Text(text).font(.system(size: size, weight: .bold, design: .rounded)).foregroundStyle(
                color),
            at: point)
    }
}
