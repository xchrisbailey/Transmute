import Foundation
import SwiftUI
import Testing
import TransmuteCore

@testable import TransmuteUI

struct AppearanceTests {
    @Test func eachChoiceForcesItsPalette() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.mocha.colorScheme == .dark)
        #expect(Appearance.latte.colorScheme == .light)
        #expect(Appearance.allCases.count == 3)
    }

    @Test func theChoiceIsReadFromDefaults() throws {
        let suite = "appearance-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(Appearance.stored(in: defaults) == .system)
        defaults.set(Appearance.latte.rawValue, forKey: Appearance.defaultsKey)
        #expect(Appearance.stored(in: defaults) == .latte)
        defaults.set("neon", forKey: Appearance.defaultsKey)
        #expect(Appearance.stored(in: defaults) == .system)
    }

    @Test(arguments: Appearance.allCases)
    func namesAreInTheCatalog(_ appearance: Appearance) throws {
        let entry = try #require(BrandAssetsTests.catalog[appearance.name.key] as? [String: Any])
        #expect((entry["comment"] as? String)?.hasPrefix("plain.") == true)
    }

    @Test func screensShowEverythingUntilAProfileSaysOtherwise() {
        #expect(EnvironmentValues().effortDisplay == .everything)
    }
}
