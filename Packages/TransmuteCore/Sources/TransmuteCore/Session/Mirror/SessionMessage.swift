import Foundation

/// Everything the two devices say to each other during a session (#15), as the `Data` the
/// transport carries.
public enum SessionMessage: Codable, Equatable, Sendable {
    /// Owner to mirror: the session as it stands.
    case snapshot(SessionSnapshot)
    /// Mirror to owner: a change to make to that workout.
    case command(SessionCommand, workoutID: UUID)
    /// The watch's latest heart rate.
    case heartRate(bpm: Double, at: Date)
    /// Owner to mirror: the session is over, finished or discarded. `healthWorkoutID` is the
    /// workout saved to Health, when one was.
    case ended(workoutID: UUID, healthWorkoutID: UUID?)
    /// Mirror to owner: send the current snapshot, e.g. after reconnecting.
    case requestSnapshot

    /// The format this build writes. Raise it when a change would mislead an older peer.
    public static let formatVersion = 1

    /// Thrown for data that isn't a message this build can read.
    public enum Failure: Error, Equatable, Sendable {
        /// Written by a newer build in a format this one doesn't know.
        case unsupportedVersion(Int)
    }

    /// The message wrapped with its format version. JSON, with dates as seconds since the
    /// reference date, which round-trips a `Date` exactly.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        return try encoder.encode(Envelope(version: Self.formatVersion, message: self))
    }

    /// Reads a message, throwing `Failure.unsupportedVersion` for a newer format and a
    /// `DecodingError` for anything else it can't make sense of, such as a kind of message
    /// added later.
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let version = try decoder.decode(Header.self, from: data).version
        guard (1...Self.formatVersion).contains(version) else { throw Failure.unsupportedVersion(version) }
        self = try decoder.decode(Envelope.self, from: data).message
    }

    private struct Header: Decodable {
        let version: Int
    }

    private struct Envelope: Codable {
        let version: Int
        let message: SessionMessage
    }
}
