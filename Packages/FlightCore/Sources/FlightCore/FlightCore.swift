/// Glidepath's rules: the simulation, levels and difficulty.
///
/// This module imports no Apple frameworks, so it builds and tests on Linux
/// too. The simulation arrives in Phase 1 (see docs/ROADMAP.md).
public enum FlightCore {
    /// Simulation steps per second. Fixed, so runs are deterministic.
    public static let tickRate = 60
}
