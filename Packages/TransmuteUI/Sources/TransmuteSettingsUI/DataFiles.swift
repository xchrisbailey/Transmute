import Foundation
import SwiftData
import SwiftUI
import TransmuteCore
import UniformTypeIdentifiers

/// The two files Settings can export (#18).
enum ExportKind: Sendable {
    /// Every logged set as CSV.
    case workouts
    /// Everything, as a JSON backup.
    case backup

    var contentType: UTType {
        switch self {
        case .workouts: .commaSeparatedText
        case .backup: .json
        }
    }

    var fileExtension: String {
        switch self {
        case .workouts: "csv"
        case .backup: "json"
        }
    }

    /// e.g. "Transmute workouts 2026-10-03". The date is the person's own, not UTC's, and is
    /// written year first so files sort by name. File names aren't translated.
    func baseName(on date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        switch self {
        case .workouts: return "Transmute workouts \(stamp)"
        case .backup: return "Transmute backup \(stamp)"
        }
    }

    func fileName(on date: Date = .now, calendar: Calendar = .current) -> String {
        "\(baseName(on: date, calendar: calendar)).\(fileExtension)"
    }
}

/// An export ready for the file exporter.
struct ExportedFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    var kind: ExportKind
    var data: Data
    /// Without the extension, which the exporter adds.
    var name: String

    init(kind: ExportKind, data: Data, on date: Date = .now) {
        self.kind = kind
        self.data = data
        self.name = kind.baseName(on: date)
    }

    init(configuration: ReadConfiguration) throws {
        kind = configuration.contentType == .json ? .backup : .workouts
        data = configuration.file.regularFileContents ?? Data()
        name = kind.baseName()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// What kind of file was picked to import (#18). Told apart by the contents, so a backup
/// renamed to .txt still imports.
enum ImportKind: Equatable {
    case backup
    case csv

    /// The types the file importer offers.
    static let contentTypes: [UTType] = [.json, .commaSeparatedText, .plainText]

    /// JSON backups start with a brace; anything else is read as CSV, which reports its own
    /// error when it isn't one.
    init(_ data: Data) {
        let utf8ByteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
        let body = data.starts(with: utf8ByteOrderMark) ? data.dropFirst(3) : data[...]
        let first = body.first { !Character(UnicodeScalar($0)).isWhitespace }
        self = first == UInt8(ascii: "{") ? .backup : .csv
    }
}

extension DataTransfer {
    /// Reads a file the person picked and imports it as whichever kind it is.
    ///
    /// Picked files are outside the sandbox, so access is opened for the read and closed again.
    /// Throws `ImportFailure.cantOpen` when the file can't be read; otherwise what the
    /// importers throw.
    static func importFile(
        at url: URL, into context: ModelContext, fallbackUnits: UnitSystem
    ) throws -> ImportSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportFailure.cantOpen }
        return try importFile(data, into: context, fallbackUnits: fallbackUnits)
    }

    static func importFile(
        _ data: Data, into context: ModelContext, fallbackUnits: UnitSystem
    ) throws -> ImportSummary {
        guard !data.isEmpty else { throw DataTransferError.emptyFile }
        switch ImportKind(data) {
        case .backup: return try importBackup(data, into: context)
        case .csv: return try importCSV(data, into: context, fallbackUnits: fallbackUnits)
        }
    }
}

/// Why an import failed before the importers saw the file.
enum ImportFailure: Error {
    case cantOpen
}
