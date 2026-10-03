import Foundation

/// Why an export or import couldn't be done. The screen picks the words (#18).
public enum DataTransferError: Error, Equatable, Sendable {
    /// The file has nothing in it.
    case emptyFile
    /// The file isn't a Transmute backup, or it's damaged. The detail is for logs, not for people.
    case unreadableBackup(detail: String)
    /// The backup was written by a newer Transmute than this one.
    case newerBackup(formatVersion: Int, supported: Int)
    /// The file isn't text, or its header row isn't one a Strong or Hevy export starts with.
    case unrecognizedCSV
}

extension DataTransferError: LocalizedError {
    /// For logs and test reports. People see plain copy chosen by the screen instead.
    public var errorDescription: String? {
        String(describing: self)
    }
}
