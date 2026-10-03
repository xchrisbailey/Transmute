import Foundation
import Testing

@testable import TransmuteCore

struct DeepLinkTests {
    @Test func linksSpellTheirURLs() {
        #expect(DeepLink.today.url.absoluteString == "transmute://today")
        #expect(DeepLink.beginToday.url.absoluteString == "transmute://today/begin")
    }

    @Test(arguments: DeepLink.allCases)
    func everyLinkReadsItsOwnURL(_ link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }

    @Test(arguments: [
        ("transmute://today", DeepLink.today), ("transmute://today/", .today), ("TRANSMUTE://Today", .today),
        ("transmute://today?from=widget", .today), ("transmute://today/begin", .beginToday),
        ("transmute://today/begin/", .beginToday), ("transmute://today/Begin#now", .beginToday),
        ("transmute:///today/begin", .beginToday),
    ])
    func urlsAreReadLeniently(_ string: String, _ link: DeepLink) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == link)
    }

    @Test(arguments: [
        "https://today/begin", "transmute://", "transmute://plan", "transmute://today/begin/now",
        "transmute://begin", "transmute:today/extra", "file:///today",
    ])
    func otherURLsAreNotLinks(_ string: String) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == nil)
    }
}
