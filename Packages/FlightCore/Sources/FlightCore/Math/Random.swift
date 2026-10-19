/// xoshiro256**: a small, fast generator whose output is identical on every
/// platform and Swift version, so seeds and replays always reproduce.
///
/// The helpers below convert raw output ourselves rather than using the
/// standard library's `random(in:using:)`, whose algorithm may change.
public struct Xoshiro256: RandomNumberGenerator, Sendable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    public init(seed: UInt64) {
        var mixer = SplitMix64(state: seed)
        s0 = mixer.next()
        s1 = mixer.next()
        s2 = mixer.next()
        s3 = mixer.next()
    }

    public mutating func next() -> UInt64 {
        let result = rotateLeft(s1 &* 5, by: 7) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotateLeft(s3, by: 45)
        return result
    }

    /// Uniform in `[0, 1)`.
    public mutating func nextUnit() -> Float {
        Float(next() >> 40) * 0x1p-24
    }

    /// Uniform in `[0, upperBound)`. `upperBound` must be positive.
    public mutating func nextInt(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(((next() >> 32) &* UInt64(upperBound)) >> 32)
    }

    private func rotateLeft(_ value: UInt64, by amount: UInt64) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }
}

/// SplitMix64, used to expand one seed into well-mixed generator states.
struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Independent random streams, so decisions that depend on how someone plays
/// never shift the arrival script.
struct RandomStreams: Sendable {
    /// Kinds, levels, edges and timing of arrivals: the same for every player with the same seed.
    var schedule: Xoshiro256
    /// Re-picks when an arrival would be unfair to the current traffic.
    var fairness: Xoshiro256

    init(seed: UInt64) {
        var mixer = SplitMix64(state: seed)
        schedule = Xoshiro256(seed: mixer.next())
        fairness = Xoshiro256(seed: mixer.next())
    }
}
