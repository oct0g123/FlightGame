import FlightCore
import SwiftUI

/// Maps between field units (origin bottom-left, `+y` up) and view points
/// (origin top-left, `+y` down), fitting the field inside the view.
struct FieldTransform {
    /// View points per field unit.
    let scale: CGFloat
    /// The field's rectangle in view coordinates.
    let rect: CGRect

    init(field size: Vec2, in viewSize: CGSize, insets: EdgeInsets) {
        let width = CGFloat(size.x)
        let height = CGFloat(size.y)
        let available = CGSize(
            width: viewSize.width - insets.leading - insets.trailing,
            height: viewSize.height - insets.top - insets.bottom)
        scale = max(min(available.width / width, available.height / height), 0.01)
        let fitted = CGSize(width: width * scale, height: height * scale)
        rect = CGRect(
            x: insets.leading + (available.width - fitted.width) / 2,
            y: insets.top + (available.height - fitted.height) / 2,
            width: fitted.width, height: fitted.height)
    }

    func point(_ field: Vec2) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(field.x) * scale, y: rect.maxY - CGFloat(field.y) * scale)
    }

    func field(_ point: CGPoint) -> Vec2 {
        Vec2(Float((point.x - rect.minX) / scale), Float((rect.maxY - point.y) / scale))
    }

    func length(_ units: Float) -> CGFloat { CGFloat(units) * scale }

    /// Field units covered by `points` view points.
    func units(_ points: CGFloat) -> Float { Float(points / scale) }
}
