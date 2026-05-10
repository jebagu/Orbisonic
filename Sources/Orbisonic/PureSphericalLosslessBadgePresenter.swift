import AudioContracts
import Foundation

struct PureSphericalLosslessBadgePresentation: Equatable {
    let text: String
}

enum PureSphericalLosslessBadgePresenter {
    static func presentation(for state: PureSphericalLosslessState) -> PureSphericalLosslessBadgePresentation? {
        guard let text = state.badgeText else { return nil }
        return PureSphericalLosslessBadgePresentation(text: text)
    }
}
