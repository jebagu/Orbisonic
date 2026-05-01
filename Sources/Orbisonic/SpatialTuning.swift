struct SpatialTuning {
    var preset: SpatialPreset
    var frontAngle: Double
    var rearAngle: Double

    static let `default` = SpatialPreset.immersiveWrap.defaults
}
