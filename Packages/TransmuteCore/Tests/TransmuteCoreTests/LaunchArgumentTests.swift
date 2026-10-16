import Testing

@testable import TransmuteCore

struct LaunchArgumentTests {
    @Test func flagsKeepTheirSpelling() {
        #expect(
            LaunchArgument.allCases.map(\.flag) == ["-initCloudKitSchema", "-seedSample", "-sampleSession", "-sampleRest"])
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
        let arguments = ["Transmute", "-AppleLanguages", "(de)", "seedSample", "--seedSample", "-seedSamples", "-SEEDSAMPLE"]
        #expect(LaunchArgument.passed(in: arguments).isEmpty)
    }
}
