import Foundation

/// A 2D point or direction in field units. `+x` is east and `+y` points away
/// from the player.
public struct Vec2: Hashable, Sendable {
    public var x: Float
    public var y: Float

    public init(_ x: Float, _ y: Float) {
        self.x = x
        self.y = y
    }

    /// The unit vector along `heading` (radians counter-clockwise from `+x`).
    public init(heading: Float) {
        self.init(cos(heading), sin(heading))
    }

    public static let zero = Vec2(0, 0)

    public var length: Float { lengthSquared.squareRoot() }
    public var lengthSquared: Float { x * x + y * y }

    /// Direction in radians counter-clockwise from `+x`.
    public var heading: Float { atan2(y, x) }

    /// This vector scaled to length 1, or zero if it has no length.
    public var normalized: Vec2 {
        let length = length
        return length > 0 ? self / length : .zero
    }

    public func dot(_ other: Vec2) -> Float { x * other.x + y * other.y }

    public func distance(to other: Vec2) -> Float { (other - self).length }

    /// The point `t` of the way from this point to `other`.
    public func lerp(to other: Vec2, _ t: Float) -> Vec2 { self + (other - self) * t }

    public static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x + rhs.x, lhs.y + rhs.y) }
    public static func - (lhs: Vec2, rhs: Vec2) -> Vec2 { Vec2(lhs.x - rhs.x, lhs.y - rhs.y) }
    public static func * (lhs: Vec2, rhs: Float) -> Vec2 { Vec2(lhs.x * rhs, lhs.y * rhs) }
    public static func / (lhs: Vec2, rhs: Float) -> Vec2 { Vec2(lhs.x / rhs, lhs.y / rhs) }
    public static prefix func - (vector: Vec2) -> Vec2 { Vec2(-vector.x, -vector.y) }
    public static func += (lhs: inout Vec2, rhs: Vec2) { lhs = lhs + rhs }
}

/// Encoded as a two-element array, `[x, y]`, to keep level files compact.
extension Vec2: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init(try container.decode(Float.self), try container.decode(Float.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

/// Heading arithmetic. Headings are radians counter-clockwise from `+x`.
public enum Angles {
    public static func radians(fromDegrees degrees: Float) -> Float { degrees * .pi / 180 }
    public static func degrees(fromRadians radians: Float) -> Float { radians * 180 / .pi }

    /// The same angle, in `(-π, π]`.
    public static func wrap(_ angle: Float) -> Float {
        var wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if wrapped <= -.pi { wrapped += 2 * .pi }
        if wrapped > .pi { wrapped -= 2 * .pi }
        return wrapped
    }

    /// The smallest signed turn from `from` to `to`, in `(-π, π]`.
    public static func delta(from: Float, to: Float) -> Float { wrap(to - from) }
}
