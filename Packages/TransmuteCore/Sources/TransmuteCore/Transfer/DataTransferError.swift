import Foundation

/// Why an export or import couldn't be done. The screen picks the words.
public enum DataTransferError: Error, Equatable, Sendable {
    case emptyFile
    /// The file isn't a Transmute backup, or it's damaged. The detail is for logs, not for people.
    case unreadableBackup(detail: String)
    case newerBackup(formatVersion: Int, supported: Int)
    /// The file isn't text, or its header row isn't one a Strong or Hevy export starts with.
    case unrecognizedCSV
    /// The picked file couldn't be read at all.
    case cantOpen
    /// The store failed while saving the import. Nothing was kept. The detail is for logs.
    case saveFailed(detail: String)

    /// `error` if it is already one of these; otherwise the store's error, as `saveFailed`.
    public init(wrapping error: any Error) {
        self = (error as? DataTransferError) ?? .saveFailed(detail: String(describing: error))
    }
}

extension DataTransferError: LocalizedError {
    /// For logs and test reports. People see plain copy chosen by the screen instead.
    public var errorDescription: String? {
        String(describing: self)
    }
}
