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

    public var flag: String { "-\(rawValue)" }

    /// The flags present in `arguments`, which are the process's own by default.
    public static func passed(in arguments: [String] = ProcessInfo.processInfo.arguments) -> Set<LaunchArgument> {
        Set(allCases.filter { arguments.contains($0.flag) })
    }
}
