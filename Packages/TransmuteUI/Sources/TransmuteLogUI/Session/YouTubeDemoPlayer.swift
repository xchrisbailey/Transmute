#if os(iOS)
    import Foundation
    import Observation
    import UIKit
    import WebKit

    /// Only public iframe API calls cross this adapter; no workout data reaches the page.
    @MainActor @Observable
    final class YouTubeDemoPlayer: NSObject, DemoPlayer, WKNavigationDelegate, WKUIDelegate {
        var onEvent: ((DemoPlayerEvent, UUID) -> Void)?
        private(set) var webView: WKWebView?
        private var attempt: UUID?
        private var loadTimeout: Task<Void, Never>?
        private var origin: URL? {
            Bundle.main.bundleIdentifier.flatMap { URL(string: "https://\($0.lowercased())") }
        }

        func load(videoID: String, attempt: UUID) {
            stop()
            self.attempt = attempt
            guard let origin else {
                onEvent?(.failed, attempt)
                return
            }
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = true
            configuration.allowsPictureInPictureMediaPlayback = false
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.websiteDataStore = .nonPersistent()
            configuration.userContentController.add(Bridge(owner: self), name: "demo")
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.scrollView.isScrollEnabled = false
            webView.isOpaque = false
            self.webView = webView
            // YouTube requires the installed app's identity as the HTTP referrer. Their
            // documented local-HTML integration uses loadHTMLString's baseURL for this.
            webView.loadHTMLString(Self.page(videoID: videoID, attempt: attempt, origin: origin), baseURL: origin)
            loadTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(25)) } catch { return }
                guard let self, self.attempt == attempt else { return }
                self.onEvent?(.failed, attempt)
            }
        }

        func play() {
            webView?.evaluateJavaScript("player?.playVideo()", completionHandler: nil)
        }

        func pause() {
            // Retire the web process's player, rather than trust a delayed JavaScript
            // pause to prevent resumption after a suspension or audio interruption.
            stop()
        }

        func stop() {
            loadTimeout?.cancel()
            loadTimeout = nil
            attempt = nil
            guard let webView else { return }
            webView.pauseAllMediaPlayback(completionHandler: nil)
            webView.evaluateJavaScript("player?.destroy()", completionHandler: nil)
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "demo")
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.loadHTMLString("", baseURL: nil)
            self.webView = nil
        }

        fileprivate func receive(_ message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                message.frameInfo.securityOrigin.host == origin?.host,
                let body = message.body as? [String: String],
                let attempt, body["attempt"] == attempt.uuidString
            else { return }
            let event: DemoPlayerEvent
            switch body["event"] {
            case "ready":
                loadTimeout?.cancel()
                event = .ready
            case "playing": event = .playing
            case "paused": event = .paused
            case "failed": event = .failed
            default: return
            }
            onEvent?(event, attempt)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failed(webView)
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
        ) {
            failed(webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            failed(webView)
        }

        private func failed(_ webView: WKWebView) {
            guard webView === self.webView, let attempt else { return }
            onEvent?(.failed, attempt)
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if action.targetFrame == nil {
                decisionHandler(.allow)
                return
            }
            guard action.targetFrame?.isMainFrame != false else {
                decisionHandler(.allow)
                return
            }
            if action.navigationType == .linkActivated, let url = action.request.url, url.scheme == "https" {
                if let attempt { onEvent?(.mainFrameLink(url), attempt) }
                decisionHandler(.cancel)
            } else {
                let url = action.request.url
                decisionHandler(url?.host == origin?.host || url?.absoluteString == "about:blank" ? .allow : .cancel)
            }
        }

        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction, windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = action.request.url, url.scheme == "https" {
                if let attempt { onEvent?(.newWindowLink(url), attempt) }
            }
            return nil
        }

        private static func page(videoID: String, attempt: UUID, origin: URL) -> String {
            // The ID has already passed library validation (11 ASCII URL-safe characters).
            // No exercise name, cues, Health data or workout identifiers enter this HTML.
            """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>html,body{margin:0;width:100%;height:100%;background:transparent}
            #player{width:100%;height:100%;min-width:200px;min-height:200px}</style>
            </head><body><div id="player"></div><script>
            let player, buffering;
            function send(event){window.webkit.messageHandlers.demo.postMessage({event,attempt:'\(attempt.uuidString)'})}
            function onYouTubeIframeAPIReady(){
              player=new YT.Player('player',{
                width:'100%',height:'100%',videoId:'\(videoID)',
                playerVars:{autoplay:0,playsinline:1,controls:1,origin:'\(origin.absoluteString)'},
                events:{onReady:()=>send('ready'),onError:()=>send('failed'),
                  onAutoplayBlocked:()=>send('paused'),onStateChange:(e)=>{
                    clearTimeout(buffering);
                    if(e.data===1)send('playing');
                    if(e.data===2||e.data===0)send('paused');
                    if(e.data===3)buffering=setTimeout(()=>send('failed'),30000);
                  }}
              });
            }
            document.addEventListener('visibilitychange',()=>{if(document.hidden&&player)player.pauseVideo()});
            </script><script src="https://www.youtube.com/iframe_api" onerror="send('failed')"></script>
            </body></html>
            """
        }
    }

    @MainActor
    private final class Bridge: NSObject, WKScriptMessageHandler {
        weak var owner: YouTubeDemoPlayer?

        init(owner: YouTubeDemoPlayer) { self.owner = owner }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            owner?.receive(message)
        }
    }
#endif
