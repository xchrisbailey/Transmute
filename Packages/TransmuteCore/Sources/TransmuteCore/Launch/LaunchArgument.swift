import Foundation

/// The launch arguments a debug build reads, for development and screenshots.
public enum LaunchArgument: String, CaseIterable, Sendable {
    /// Creates every record type and field in CloudKit's Development environment, then the
    /// app carries on launching. `docs/TESTFLIGHT.md` relies on this spelling.
    case initCloudKitSchema
    /// Fills an empty store with the sample tennis player, plan and log.
    case seedSample
    /// Also starts this week's first session, to see the session screen.
    case sampleSession
    /// On the watch, also logs the session's first set, to see the rest ring.
    case sampleRest
    /// Followed by a `transmute://` URL, goes there once launched, through `DeepLinkRouter`
    /// like an App Intent does. `simctl openurl` stops at a system prompt that nothing can tap.
    case openLink

    public var flag: String { "-\(rawValue)" }

    /// The flags present in `arguments`, which are the process's own by default.
    public static func passed(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Set<LaunchArgument> {
        Set(allCases.filter { arguments.contains($0.flag) })
    }

    /// The place `-openLink` names, from the argument after it. `nil` with no flag, no value, or a
    /// URL that isn't a `DeepLink`.
    public static func deepLink(in arguments: [String] = ProcessInfo.processInfo.arguments) -> DeepLink? {
        guard let flag = arguments.firstIndex(of: openLink.flag), arguments.indices.contains(flag + 1),
            let url = URL(string: arguments[flag + 1])
        else { return nil }
        return DeepLink(url: url)
    }
}
