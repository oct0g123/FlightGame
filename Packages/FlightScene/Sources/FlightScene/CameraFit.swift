import Foundation

/// Places the flat-screen camera so the whole field fits the view at any aspect ratio.
///
/// The camera looks at the field's centre from `pitch` above the horizon. A
/// ground point `(x, z)` (with `+z` toward the camera) sits at depth
/// `d - z·cos(pitch)` along the view direction, `x` to the side and
/// `z·sin(pitch)` below centre. The near corners are the tightest, which gives
///
///     d = Z·cos(pitch) + max(X / tan(h), Z·sin(pitch) / tan(v))
///
/// where `X` and `Z` are the field's half-width and half-depth (plus margin),
/// and `v` and `h` are the vertical and horizontal half-angles of the view.
struct CameraFit {
    /// Field width and depth, in metres.
    var fieldSize: SIMD2<Float>
    /// Angle above the horizon, in radians.
    var pitch: Float
    /// Vertical field of view, in radians.
    var verticalFieldOfView: Float
    /// Extra space around the field, as a fraction of its size.
    var margin: Float = 0.08

    /// Distance from the field's centre to the camera for a view of the given width / height.
    func distance(aspect: Float) -> Float {
        let halfWidth = fieldSize.x / 2 * (1 + margin)
        let halfDepth = fieldSize.y / 2 * (1 + margin)
        let tanVertical = tan(verticalFieldOfView / 2)
        let tanHorizontal = tanVertical * max(aspect, 0.01)
        let widthFit = halfWidth / tanHorizontal
        let depthFit = halfDepth * sin(pitch) / tanVertical
        return halfDepth * cos(pitch) + max(widthFit, depthFit)
    }

    /// Camera position relative to the field's centre, on the side facing `+z`.
    func position(aspect: Float) -> SIMD3<Float> {
        let distance = distance(aspect: aspect)
        return [0, distance * sin(pitch), distance * cos(pitch)]
    }
}
