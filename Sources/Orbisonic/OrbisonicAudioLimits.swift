enum OrbisonicAudioLimits {
    static let maxSourceChannelCount = 64

    static func supportsSourceChannelCount(_ count: Int) -> Bool {
        count >= 1 && count <= maxSourceChannelCount
    }
}
