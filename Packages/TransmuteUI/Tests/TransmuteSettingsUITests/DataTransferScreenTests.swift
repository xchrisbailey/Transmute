import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

@testable import TransmuteSettingsUI

@MainActor
struct DataTransferScreenTests {
    func text(_ resources: [LocalizedStringResource]) -> [String] {
        resources.map { String(localized: $0) }
    }

    // MARK: Export

    @Test func exportNamesCarryThePersonsDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // 2026-10-04 02:30 UTC is still the evening of the 3rd in New York.
        let date = Date(timeIntervalSince1970: 1_791_081_000)
        #expect(ExportKind.workouts.fileName(on: date, calendar: calendar) == "Transmute workouts 2026-10-03.csv")
        #expect(ExportKind.backup.fileName(on: date, calendar: calendar) == "Transmute backup 2026-10-03.json")
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(ExportKind.backup.baseName(on: date, calendar: calendar) == "Transmute backup 2026-10-04")
        #expect(ExportKind.workouts.contentType == .commaSeparatedText)
        #expect(ExportKind.backup.contentType == .json)
    }

    // MARK: Import

    @Test func filesAreToldApartByTheirContents() {
        #expect(ImportKind(Data("{\"formatVersion\":1}".utf8)) == .backup)
        #expect(ImportKind(Data("\n  {".utf8)) == .backup)
        #expect(ImportKind(Data([0xEF, 0xBB, 0xBF] + Array("{}".utf8))) == .backup)
        #expect(ImportKind(Data("Date,Workout Name,Exercise Name".utf8)) == .csv)
        #expect(ImportKind(Data()) == .csv)
    }

    @Test func aBackupGoesBackInThroughTheSameDoor() throws {
        let source = try SampleData.previewContainer()
        let backup = try DataTransfer.exportBackup(from: source.mainContext)
        let csv = try DataTransfer.exportCSV(from: source.mainContext)

        let fresh = try TransmuteStore.makeContainer(.inMemory)
        let summary = try DataTransfer.importFile(backup, into: fresh.mainContext, fallbackUnits: .metric)
        #expect(summary.source == .backup)
        #expect(summary.profile == .added)
        #expect(try fresh.mainContext.fetchCount(FetchDescriptor<Profile>()) == 1)

        // Transmute's own CSV isn't a Strong or Hevy export, and says so.
        #expect(throws: DataTransferError.unrecognizedCSV) {
            try DataTransfer.importFile(csv, into: fresh.mainContext, fallbackUnits: .metric)
        }
        #expect(throws: DataTransferError.emptyFile) {
            try DataTransfer.importFile(Data(), into: fresh.mainContext, fallbackUnits: .metric)
        }
        #expect(throws: ImportFailure.cantOpen) {
            try DataTransfer.importFile(
                at: URL(fileURLWithPath: "/nonexistent/\(UUID()).json"), into: fresh.mainContext,
                fallbackUnits: .metric)
        }
    }

    @Test func aBackupReportSaysWhatWasAddedAndSkipped() {
        var summary = ImportSummary(source: .backup)
        summary.profile = .kept
        summary.workouts = .init(added: 12, skipped: 3)
        summary.setsAdded = 240
        summary.plans = .init(added: 1, skipped: 0)
        summary.bodyweights = .init(added: 4)
        summary.recordsAdded = 9
        summary.customExercises = .init(added: 2)
        let report = ImportReport(summary)
        #expect(report.succeeded)
        #expect(String(localized: report.heading) == "Import finished")
        #expect(
            text(report.lines) == [
                "From a Transmute backup.", "The profile already here was kept as it is.", "Workouts added: 12",
                "Sets added: 240", "Workouts already here, skipped: 3", "Plans added: 1",
                "Bodyweight entries added: 4", "Records added: 9", "Your own exercises added: 2",
            ])
    }

    @Test func aSpreadsheetReportNamesTheExercisesItAdded() {
        var summary = ImportSummary(source: .strong)
        summary.workouts = .init(added: 2)
        summary.setsAdded = 11
        summary.customExercises = .init(added: 2)
        summary.unmatchedExerciseNames = ["Sled Drag", "Zercher Carry"]
        summary.unreadableRows = 1
        let lines = text(ImportReport(summary).lines)
        #expect(lines.first == "From a Strong export.")
        #expect(
            lines.contains(
                "These exercise names aren't in Transmute's library, so they were added as your own exercises: "
                    + "Sled Drag and Zercher Carry."))
        #expect(!lines.contains { $0.hasPrefix("Your own exercises added") })
        #expect(lines.last == "Rows that couldn't be read and were left out: 1")
    }

    @Test func importingTheSameFileAgainSaysNothingIsNew() {
        var summary = ImportSummary(source: .hevy)
        summary.workouts = .init(added: 0, skipped: 5)
        let report = ImportReport(summary)
        #expect(String(localized: report.heading) == "Nothing new to import")
        #expect(
            text(report.lines) == [
                "From a Hevy export.", "Everything in this file is already in Transmute.",
                "Workouts already here, skipped: 5",
            ])
        #expect(report.spoken.hasPrefix("Nothing new to import From a Hevy export."))
    }

    @Test func everyFailureHasItsOwnPlainWords() {
        let errors: [any Error] = [
            DataTransferError.emptyFile, DataTransferError.unreadableBackup(detail: "x"),
            DataTransferError.newerBackup(formatVersion: 9, supported: 1), DataTransferError.unrecognizedCSV,
            ImportFailure.cantOpen, CocoaError(.fileWriteUnknown),
        ]
        let messages = errors.map { ImportReport.message(for: $0) }
        #expect(Set(messages.map(\.key)).count == errors.count)
        for message in messages {
            #expect(message.key.hasPrefix("plain.settings.import.error."))
            #expect(String(localized: message).hasSuffix("Nothing was changed."))
        }
        let report = ImportReport(DataTransferError.newerBackup(formatVersion: 9, supported: 1))
        #expect(!report.succeeded)
        #expect(text(report.lines).first?.contains("newer version of Transmute") == true)
    }

    // MARK: Delete

    @Test func resetClearsTransmutesKeysAndNothingElse() throws {
        let suite = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let ours = [
            Appearance.defaultsKey, IntelligenceSettings.routeKey, "rootTab", "planGrid", "reminders.trainingDay",
            "reminders.trainingDay.minutes", "reminders.missedDay",
        ]
        for key in ours { defaults.set("x", forKey: key) }
        defaults.set("kept", forKey: "somebodyElse")
        DefaultsReset.run(in: defaults)
        for key in ours {
            #expect(defaults.object(forKey: key) == nil, "\(key)")
        }
        #expect(defaults.string(forKey: "somebodyElse") == "kept")
        #expect(Appearance.stored(in: defaults) == .system)
        #expect(IntelligenceSettings.load(from: defaults).route == .onDeviceOnly)
    }

    @Test func deleteAllEmptiesTheStoreResetsDefaultsAndRecordsTheOutcome() async throws {
        let suite = "settings-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Appearance.latte.rawValue, forKey: Appearance.defaultsKey)
        let container = try SampleData.previewContainer()

        let outcome = try await DataEraser.eraseEverything(
            in: container, link: nil, defaults: defaults, clearsNotifications: false)

        // An in-memory store doesn't sync, so iCloud is never asked.
        #expect(outcome == .localOnly)
        for model in SchemaV1.models {
            #expect(try count(model, in: container.mainContext) == 0, "\(model)")
        }
        #expect(defaults.object(forKey: Appearance.defaultsKey) == nil)
        #expect(defaults.string(forKey: ErasureOutcome.defaultsKey) == ErasureOutcome.localOnly.rawValue)
        ErasureNotice.clear(in: defaults)
        #expect(defaults.object(forKey: ErasureOutcome.defaultsKey) == nil)
    }

    private func count<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }
}
