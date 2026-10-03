import Foundation

/// Where a `transmute://` URL takes the app (#19). Widgets build these and the apps read
/// them, so the URLs are spelled in one place.
public enum DeepLink: String, CaseIterable, Hashable, Sendable {
    /// `transmute://today`: the Today screen.
    case today = "today"
    /// `transmute://today/begin`: the Today screen, starting today's session. With a workout
    /// already running it goes back into that one.
    case beginToday = "today/begin"

    /// The URL scheme the iPhone and Mac apps register.
    public static let scheme = "transmute"

    /// Reads a URL. The scheme and the words are matched whatever their case, and a trailing
    /// slash, query or fragment is ignored. `nil` for another scheme or a place the app
    /// doesn't know.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        let parts = ([url.host(percentEncoded: false) ?? ""] + url.pathComponents)
            .filter { !$0.isEmpty && $0 != "/" }
        self.init(rawValue: parts.joined(separator: "/").lowercased())
    }

    public var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }
}
