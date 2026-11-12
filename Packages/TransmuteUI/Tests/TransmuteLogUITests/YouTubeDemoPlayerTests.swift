#if os(iOS)
    import Foundation
    import Testing
    import WebKit

    @testable import TransmuteLogUI

    @MainActor
    struct YouTubeDemoPlayerTests {
        @Test func retiredNavigationCannotBeRetaggedAsTheReplacementAttempt() throws {
            let player = YouTubeDemoPlayer(makeWebView: { configuration in
                NonLoadingWebView(frame: .zero, configuration: configuration)
            })
            defer { player.stop() }
            var attempts: [UUID] = []
            player.onEvent = { event, attempt in
                if case .newWindowLink = event { attempts.append(attempt) }
            }
            player.load(videoID: "TESTONLY001", attempt: UUID())
            let retired = try #require(player.webView)
            player.stop()
            let replacementAttempt = UUID()
            player.load(videoID: "TESTONLY001", attempt: replacementAttempt)
            let replacement = try #require(player.webView)
            let action = WindowLinkAction()
            var policy: WKNavigationActionPolicy?
            player.webView(retired, decidePolicyFor: action) { policy = $0 }
            #expect(policy == .cancel, "A retired source must be rejected before the new-window allow branch")
            #expect(
                player.webView(
                    retired, createWebViewWith: retired.configuration,
                    for: action, windowFeatures: WKWindowFeatures()) == nil)
            #expect(attempts.isEmpty, "The adapter must not retag a retired callback with the replacement's attempt")
            #expect(player.webView === replacement)
            player.webView(replacement, decidePolicyFor: action) { policy = $0 }
            #expect(policy == .allow)
            #expect(
                player.webView(
                    replacement, createWebViewWith: replacement.configuration,
                    for: action, windowFeatures: WKWindowFeatures()) == nil)
            #expect(attempts == [replacementAttempt])
        }
    }

    /// Only HTML/network loading is suppressed; delegate callbacks run through the
    /// actual adapter using distinct WKWebView identities and an external action fixture.
    @MainActor
    private final class NonLoadingWebView: WKWebView {
        override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? { nil }
    }

    @MainActor
    private final class WindowLinkAction: WKNavigationAction {
        override var targetFrame: WKFrameInfo? { nil }
        override var request: URLRequest {
            URLRequest(url: URL(string: "https://example.invalid/link")!)
        }
    }
#endif
