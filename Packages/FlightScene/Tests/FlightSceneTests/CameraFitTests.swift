import Foundation
import Testing

@testable import FlightScene

struct CameraFitTests {
    let fit = CameraFit(
        fieldSize: [1.0, 0.625],
        pitch: 55 * .pi / 180,
        verticalFieldOfView: 30 * .pi / 180
    )

    /// Projects a ground point to normalised screen coordinates (-1…1 on both axes).
    func project(x: Float, z: Float, aspect: Float) -> SIMD2<Float> {
        let distance = fit.distance(aspect: aspect)
        let depth = distance - z * cos(fit.pitch)
        let tanVertical = tan(fit.verticalFieldOfView / 2)
        return [x / (depth * tanVertical * aspect), -z * sin(fit.pitch) / (depth * tanVertical)]
    }

    @Test(arguments: [0.5, 0.69, 1.0, 1.33, 1.6, 2.17, 3.0] as [Float])
    func wholeFieldFitsTheView(aspect: Float) {
        let halfWidth = fit.fieldSize.x / 2 * (1 + fit.margin)
        let halfDepth = fit.fieldSize.y / 2 * (1 + fit.margin)
        var largest: Float = 0
        for x in [-halfWidth, halfWidth] {
            for z in [-halfDepth, halfDepth] {
                let point = project(x: x, z: z, aspect: aspect)
                #expect(abs(point.x) <= 1.0001)
                #expect(abs(point.y) <= 1.0001)
                largest = max(largest, abs(point.x), abs(point.y))
            }
        }
        // Tight: one edge of the field (plus margin) touches the edge of the view.
        #expect(abs(largest - 1) < 0.001)
    }

    @Test func portraitPullsTheCameraBack() {
        #expect(fit.distance(aspect: 834.0 / 1210.0) > fit.distance(aspect: 1210.0 / 834.0) * 1.5)
    }

    @Test func cameraLooksDownAtThePitch() {
        let position = fit.position(aspect: 1.6)
        let angle = atan2(position.y, position.z)
        #expect(abs(angle - fit.pitch) < 0.0001)
    }
}
