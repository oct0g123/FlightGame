extension Aircraft {
    /// Seconds a helicopter takes to settle on the pad.
    static let padSettleTime: Float = 1.2
    /// Fraction of approach speed left at the end of the landing roll.
    static let rollOutSpeedFraction: Float = 0.45

    mutating func touchDown(on runway: Runway) {
        state = .landing(runway: runway.id, elapsed: 0)
        altitude = 0
        path = nil
        turnRate = 0
        if !runway.anyHeading { heading = runway.heading }
    }

    /// One tick of the landing roll (or settling on a pad). Returns true when it's done.
    mutating func roll(on runway: Runway) -> Bool {
        guard case .landing(let runwayID, let elapsed) = state else { return false }
        let dt = Simulation.dt
        let now = elapsed + dt
        state = .landing(runway: runwayID, elapsed: now)

        if runway.anyHeading || runway.length <= 0 {
            position = position.lerp(to: runway.threshold, min(dt * 4, 1))
            speed = max(0, speed - spec.speed * dt)
            return now >= Self.padSettleTime
        }

        // Even deceleration from approach speed to the roll-out speed over the runway.
        let approach = spec.speed
        let final = approach * Self.rollOutSpeedFraction
        let deceleration = (approach * approach - final * final) / (2 * runway.length)
        speed = max(final, speed - deceleration * dt)
        position += runway.direction * (speed * dt)
        return (position - runway.threshold).dot(runway.direction) >= runway.length
    }
}
