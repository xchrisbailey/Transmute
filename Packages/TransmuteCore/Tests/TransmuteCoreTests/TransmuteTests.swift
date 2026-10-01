import Testing

@testable import TransmuteCore

struct TransmuteTests {
    @Test func identifiersShareThePrefix() {
        #expect(Transmute.cloudKitContainer == "iCloud.\(Transmute.bundlePrefix)")
        #expect(Transmute.appGroup == "group.\(Transmute.bundlePrefix)")
    }
}
