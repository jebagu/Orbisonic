import AVFoundation

struct SpatialTuning {
    var preset: SpatialPreset
    var frontAngle: Double
    var rearAngle: Double
    var headTrackingEnabled: Bool

    static let `default` = SpatialPreset.immersiveWrap.defaults

    func position(for channel: SurroundChannel) -> AVAudio3DPoint {
        let placement = placement(for: channel.role)
        return Self.cartesianPoint(
            azimuth: placement.azimuth,
            elevation: placement.elevation,
            distance: placement.distance
        )
    }

    static func cartesianPoint(azimuth: Double, elevation: Double, distance: Double) -> AVAudio3DPoint {
        let azimuthRadians = azimuth * .pi / 180
        let elevationRadians = elevation * .pi / 180
        let x = -sin(azimuthRadians) * cos(elevationRadians) * distance
        let y = sin(elevationRadians) * distance
        // AVAudioEnvironmentNode defines "forward" as the negative z-axis.
        let z = -cos(azimuthRadians) * cos(elevationRadians) * distance
        return AVAudio3DPoint(x: Float(x), y: Float(y), z: Float(z))
    }

    private func placement(for role: SurroundChannelRole) -> (azimuth: Double, elevation: Double, distance: Double) {
        switch role {
        case .frontLeft:
            return (frontAngle, 4, 1.10)
        case .frontRight:
            return (-frontAngle, 4, 1.10)
        case .center:
            return (0, 3, 0.95)
        case .lfe:
            return (-132, -16, 1.02)
        case .lfe2:
            return (132, -16, 1.02)
        case .frontLeftCenter:
            return (frontAngle * 0.5, 4, 1.02)
        case .frontRightCenter:
            return (-frontAngle * 0.5, 4, 1.02)
        case .wideLeft:
            return (68, 6, 1.18)
        case .wideRight:
            return (-68, 6, 1.18)
        case .sideLeft:
            return (108, 10, 1.22)
        case .sideRight:
            return (-108, 10, 1.22)
        case .rearLeft:
            return (rearAngle, 14, 1.28)
        case .rearRight:
            return (-rearAngle, 14, 1.28)
        case .rearCenter:
            return (180, 12, 1.25)
        case .topFrontLeft:
            return (frontAngle, 52, 1.34)
        case .topFrontCenter:
            return (0, 54, 1.30)
        case .topFrontRight:
            return (-frontAngle, 52, 1.34)
        case .topMiddleLeft:
            return (92, 64, 1.30)
        case .topMiddleCenter:
            return (0, 68, 1.26)
        case .topMiddleRight:
            return (-92, 64, 1.30)
        case .topRearLeft:
            return (rearAngle, 58, 1.36)
        case .topRearCenter:
            return (180, 60, 1.32)
        case .topRearRight:
            return (-rearAngle, 58, 1.36)
        case .discrete(let index):
            let count = max(index + 1, 1)
            let spread = max(Double(count), 8)
            let azimuth = 180 - (360 / spread) * Double(index)
            return (azimuth, 8, 1.18)
        }
    }
}
