import Testing
@testable import TransmuteUI

struct PlaceholderRootTests {
    @MainActor @Test func placeholderStoresPlatform() {
        #expect(PlaceholderRoot(platform: "iPhone").platform == "iPhone")
    }
}
