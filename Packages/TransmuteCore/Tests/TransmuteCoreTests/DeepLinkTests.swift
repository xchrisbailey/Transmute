import Foundation
import Testing

@testable import TransmuteCore

struct DeepLinkTests {
    @Test func linksSpellTheirURLs() {
        #expect(DeepLink.today.url.absoluteString == "transmute://today")
        #expect(DeepLink.beginToday.url.absoluteString == "transmute://today/begin")
        #expect(DeepLink.log.url.absoluteString == "transmute://log")
        #expect(DeepLink.plan.url.absoluteString == "transmute://plan")
        #expect(
            DeepLink.workout(Self.id).url.absoluteString == "transmute://log/0f8fad5b-d9cb-469f-a165-70867728950e")
    }

    static let id = UUID(uuidString: "0F8FAD5B-D9CB-469F-A165-70867728950E")!

    @Test(arguments: [DeepLink.today, .beginToday, .log, .workout(id), .plan])
    func everyLinkReadsItsOwnURL(_ link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }

    @Test(arguments: [
        ("transmute://today", DeepLink.today), ("transmute://today/", .today), ("TRANSMUTE://Today", .today),
        ("transmute://today?from=widget", .today), ("transmute://today/begin", .beginToday),
        ("transmute://today/begin/", .beginToday), ("transmute://today/Begin#now", .beginToday),
        ("transmute:///today/begin", .beginToday), ("transmute://Log/", .log), ("transmute://plan?x=1", .plan),
        ("transmute://log/0F8FAD5B-D9CB-469F-A165-70867728950E", .workout(id)),
        ("transmute://log/0f8fad5b-d9cb-469f-a165-70867728950e/", .workout(id)),
    ])
    func urlsAreReadLeniently(_ string: String, _ link: DeepLink) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == link)
    }

    @Test(arguments: [
        "https://today/begin", "transmute://", "transmute://plan/1", "transmute://today/begin/now",
        "transmute://log/not-an-id",
        "transmute://begin", "transmute:today/extra", "file:///today",
    ])
    func otherURLsAreNotLinks(_ string: String) throws {
        #expect(DeepLink(url: try #require(URL(string: string))) == nil)
    }

    @MainActor @Test func theRouterHandsALinkOverOnce() {
        let router = DeepLinkRouter()
        #expect(router.take() == nil)
        router.open(.today)
        router.open(.beginToday)
        #expect(router.pending == .beginToday)
        #expect(router.take() == .beginToday)
        #expect(router.pending == nil)
        #expect(router.take() == nil)
    }
}
