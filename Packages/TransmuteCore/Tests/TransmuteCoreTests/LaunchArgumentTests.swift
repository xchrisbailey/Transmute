import Foundation
import Testing

@testable import TransmuteCore

struct LaunchArgumentTests {
    @Test func flagsKeepTheirSpelling() {
        #expect(
            LaunchArgument.allCases.map(\.flag) == [
                "-initCloudKitSchema", "-seedSample", "-sampleSession", "-sampleRest", "-openLink",
            ])
    }

    @Test func noArgumentsPassNoFlags() {
        #expect(LaunchArgument.passed(in: ["/path/to/Transmute"]).isEmpty)
    }

    @Test func eachFlagIsRead() {
        for argument in LaunchArgument.allCases {
            #expect(LaunchArgument.passed(in: ["Transmute", argument.flag]) == [argument])
        }
    }

    @Test func severalFlagsAreReadTogether() {
        let passed = LaunchArgument.passed(in: ["Transmute", "-seedSample", "-sampleSession", "-sampleRest"])
        #expect(passed == [.seedSample, .sampleSession, .sampleRest])
    }

    @Test func otherArgumentsAreIgnored() {
        let arguments = [
            "Transmute", "-AppleLanguages", "(de)", "seedSample", "--seedSample", "-seedSamples", "-SEEDSAMPLE",
        ]
        #expect(LaunchArgument.passed(in: arguments).isEmpty)
    }

    @Test func openLinkReadsTheDeepLinkAfterItsFlag() {
        let id = UUID(uuidString: "0F8FAD5B-D9CB-469F-A165-70867728950E")!
        #expect(LaunchArgument.deepLink(in: ["Transmute", "-openLink", "transmute://plan"]) == .plan)
        #expect(LaunchArgument.deepLink(in: ["Transmute", "-openLink", "transmute://log/\(id)"]) == .workout(id))
        let withSeed = ["Transmute", "-seedSample", "-openLink", "transmute://today/begin"]
        #expect(LaunchArgument.deepLink(in: withSeed) == .beginToday)
    }

    @Test func openLinkIgnoresAMissingOrUnknownLink() {
        #expect(LaunchArgument.deepLink(in: ["Transmute"]) == nil)
        #expect(LaunchArgument.deepLink(in: ["Transmute", "-openLink"]) == nil)
        #expect(LaunchArgument.deepLink(in: ["Transmute", "-openLink", "https://example.com"]) == nil)
        #expect(LaunchArgument.deepLink(in: ["Transmute", "-openLink", "transmute://nowhere"]) == nil)
    }
}
