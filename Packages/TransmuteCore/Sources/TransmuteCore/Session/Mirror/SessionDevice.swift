import Foundation

/// A device a session can run on. The one that starts a workout owns it for as long as it
/// runs; the others mirror it (#15).
public enum SessionDevice: String, Codable, Sendable {
    case phone
    case watch
    case mac
}
