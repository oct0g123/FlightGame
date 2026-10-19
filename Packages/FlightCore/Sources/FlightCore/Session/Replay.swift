/// Everything needed to rerun a game exactly: map, mode, seed and commands.
public struct Replay: Codable, Equatable, Sendable {
    public static let formatVersion = 1

    public var version = formatVersion
    public let levelID: String
    public let profileID: String
    public let seed: UInt64
    public private(set) var entries: [Entry] = []

    public struct Entry: Codable, Equatable, Sendable {
        public let tick: UInt64
        public let commands: [Command]
    }

    public init(levelID: String, profileID: String, seed: UInt64) {
        self.levelID = levelID
        self.profileID = profileID
        self.seed = seed
    }

    /// The tick of the last recorded command, or 0.
    public var lastTick: UInt64 { entries.last?.tick ?? 0 }

    mutating func record(_ commands: [Command], at tick: UInt64) {
        guard !commands.isEmpty else { return }
        entries.append(Entry(tick: tick, commands: commands))
    }

    /// Replays the game from the start for `ticks` ticks.
    public func play(level: Level, profile: DifficultyProfile, ticks: UInt64) -> World {
        var world = World(level: level, profile: profile, seed: seed)
        var next = entries.startIndex
        while world.tick < ticks && !world.isOver {
            var commands: [Command] = []
            if next < entries.endIndex && entries[next].tick == world.tick {
                commands = entries[next].commands
                next += 1
            }
            Simulation.step(&world, commands: commands)
        }
        return world
    }
}

extension World {
    /// A fingerprint of the game state, for checking that two runs match.
    public var fingerprint: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ value: UInt64) {
            hash = (hash ^ value) &* 0x0000_0100_0000_01B3
        }
        mix(tick)
        mix(UInt64(landed))
        mix(UInt64(bitPattern: Int64(strikesLeft)))
        mix(UInt64(pendingArrivals.count))
        for plane in aircraft {
            mix(UInt64(plane.id.rawValue))
            mix(UInt64(plane.position.x.bitPattern) << 32 | UInt64(plane.position.y.bitPattern))
            mix(UInt64(plane.heading.bitPattern) << 32 | UInt64(plane.altitude.bitPattern))
            mix(UInt64(plane.targetLevel))
        }
        return hash
    }
}
