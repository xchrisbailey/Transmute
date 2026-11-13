import Foundation
import Testing
import TransmuteCore

@testable import TransmuteLogUI

struct DemoReportTests {
    private let kettlebell = ViewedDemo(
        exerciseID: "goblet-squat", exerciseName: "Goblet squat", equipment: [.kettlebell], videoID: "TESTONLY002")

    private func queryItems(_ url: URL) throws -> [URLQueryItem] {
        try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    }

    @Test func reportHoldsOnlyTheApprovedFields() {
        let report = DemoReport(demo: kettlebell, appVersion: "0.3.0", description: "Shows a dumbbell instead.")
        #expect(report.title == "Wrong demo video: Goblet squat (kettlebell)")
        #expect(
            report.body == """
                Wrong demo video report

                - Exercise: Goblet squat
                - Exercise ID: goblet-squat
                - Demo equipment: kettlebell
                - Video: https://www.youtube.com/watch?v=TESTONLY002
                - App version: 0.3.0

                Description:
                Shows a dumbbell instead.
                """)
        #expect(report.copyText == "\(report.title)\n\n\(report.body)")
    }

    @Test func emptyDescriptionAndUnknownVersionAreSaidPlainly() {
        let report = DemoReport(demo: kettlebell, appVersion: nil, description: " \n ")
        #expect(report.body.contains("- App version: unknown"))
        #expect(!report.body.contains("Description:"))
        let both = ViewedDemo(
            exerciseID: "goblet-squat", exerciseName: "Goblet squat", equipment: [.kettlebell, .bench],
            videoID: "TESTONLY002")
        #expect(DemoReport(demo: both, appVersion: "1").body.contains("- Demo equipment: bench, kettlebell"))
    }

    @Test func prefilledValuesAreContentNotNavigation() throws {
        let hostile =
            "Line one\nLine two & body=evil&title=x #frag ?q=1 100% +plus https://evil.example/?a=b \u{1F600} \u{E9}"
        let report = DemoReport(demo: kettlebell, appVersion: "0.3.0 & title=nope", description: hostile)
        let url = report.url
        #expect(url.scheme == "https" && url.host == "github.com")
        #expect(url.path == "/xchrisbailey/Transmute/issues/new")
        #expect(url.fragment == nil && url.user == nil && url.port == nil)
        let items = try queryItems(url)
        #expect(items.map(\.name) == ["title", "body"])
        #expect(items[0].value == report.title)
        #expect(items[1].value == report.body)
        #expect(items[1].value?.contains(hostile) == true)
        #expect(!url.absoluteString.contains(" ") && !url.absoluteString.contains("\n"))
        #expect(url.absoluteString.filter { $0 == "?" }.count == 1)
        #expect(url.absoluteString.filter { $0 == "#" }.isEmpty)
    }

    @Test func descriptionIsBoundedSoTheLinkStaysUsable() {
        var report = DemoReport(demo: kettlebell, appVersion: "0.3.0")
        report.setDescription(String(repeating: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} ", count: 400))
        #expect(report.description.utf8.count <= DemoReport.maxDescriptionBytes)
        #expect(report.url.absoluteString.utf8.count < 5000)
        #expect(report.isDescriptionCut, "The person is told when text was dropped")
        report.setDescription("short")
        #expect(report.description == "short" && !report.isDescriptionCut)
        let exact = String(repeating: "a", count: DemoReport.maxDescriptionBytes)
        report.setDescription(exact)
        #expect(report.description == exact && !report.isDescriptionCut, "Text that fits is not reported as cut")
        report.setDescription(exact + "b")
        #expect(report.description == exact && report.isDescriptionCut)
    }
}
