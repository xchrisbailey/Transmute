import Foundation
import Observation

/// Where a `transmute://` URL takes the app (#19). Widgets build these and the apps read
/// them, so the URLs are spelled in one place. App Intents send the same places through
/// `DeepLinkRouter`.
public enum DeepLink: Hashable, Sendable {
    /// `transmute://today`: the Today screen.
    case today
    /// `transmute://today/begin`: the Today screen, starting today's session. With a workout
    /// already running it goes back into that one.
    case beginToday
    /// `transmute://log`: the workout log.
    case log
    /// `transmute://log/<id>`: one logged workout, by its `Workout.id`. A workout that's gone
    /// leaves the log open.
    case workout(UUID)
    /// `transmute://plan`: the plan.
    case plan

    /// The URL scheme the iPhone and Mac apps register.
    public static let scheme = "transmute"

    /// Reads a URL. The scheme and the words are matched whatever their case, and a trailing
    /// slash, query or fragment is ignored. `nil` for another scheme or a place the app
    /// doesn't know.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        let parts = ([url.host(percentEncoded: false) ?? ""] + url.pathComponents)
            .filter { !$0.isEmpty && $0 != "/" }
            .map { $0.lowercased() }
        switch parts {
        case ["today"]: self = .today
        case ["today", "begin"]: self = .beginToday
        case ["log"]: self = .log
        case ["plan"]: self = .plan
        default:
            guard parts.count == 2, parts[0] == "log", let id = UUID(uuidString: parts[1]) else { return nil }
            self = .workout(id)
        }
    }

    /// The words after the scheme, e.g. "today/begin".
    var path: String {
        switch self {
        case .today: "today"
        case .beginToday: "today/begin"
        case .log: "log"
        case .workout(let id): "log/\(id.uuidString.lowercased())"
        case .plan: "plan"
        }
    }

    public var url: URL {
        URL(string: "\(Self.scheme)://\(path)")!
    }
}

/// Hands a `DeepLink` from an App Intent to the window (#19). An intent runs in the app's
/// process, sometimes before there's a window, so the link waits here until a root view
/// takes it.
@MainActor @Observable public final class DeepLinkRouter {
    public static let shared = DeepLinkRouter()

    /// The place an intent asked for that no window has gone to yet.
    public private(set) var pending: DeepLink?

    public init() {}

    public func open(_ link: DeepLink) {
        pending = link
    }

    /// The pending link, handed over once.
    public func take() -> DeepLink? {
        defer { pending = nil }
        return pending
    }
}
