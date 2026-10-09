import Testing

@testable import TransmuteSettingsUI

struct AboutInfoTests {
    @Test func readsTheMarketingVersionAndTheBuildNumber() {
        let info = AboutInfo(infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "42"])
        #expect(info.version == "0.1.0")
        #expect(info.build == "42")
    }

    @Test func aMissingVersionOrBuildShowsADash() {
        let noBuild = AboutInfo(infoDictionary: ["CFBundleShortVersionString": "1.2"])
        #expect(noBuild.version == "1.2")
        #expect(noBuild.build == AboutInfo.missing)

        let empty = AboutInfo(infoDictionary: [:])
        #expect(empty.version == AboutInfo.missing)
        #expect(empty.build == AboutInfo.missing)

        let none = AboutInfo(infoDictionary: nil)
        #expect(none.version == AboutInfo.missing)
        #expect(none.build == AboutInfo.missing)
    }

    @Test func aBlankOrWrongTypedValueCountsAsMissing() {
        let info = AboutInfo(infoDictionary: ["CFBundleShortVersionString": "  ", "CFBundleVersion": 7])
        #expect(info.version == AboutInfo.missing)
        #expect(info.build == AboutInfo.missing)
    }
}
