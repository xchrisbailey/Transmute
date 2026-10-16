import SwiftUI
import TransmuteCore

extension View {
    /// Hands each link an App Intent opens to `follow`, including one that was waiting since
    /// before this window existed.
    public func followsDeepLinks(_ follow: @escaping (DeepLink) -> Void) -> some View {
        modifier(DeepLinkFollowing(follow: follow))
    }
}

private struct DeepLinkFollowing: ViewModifier {
    let follow: (DeepLink) -> Void
    private let router = DeepLinkRouter.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: router.pending, initial: true) {
                if let link = router.take() { follow(link) }
            }
    }
}
