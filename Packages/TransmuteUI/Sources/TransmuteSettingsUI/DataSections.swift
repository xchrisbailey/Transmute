import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteLogUI
import TransmuteUI

/// What Transmute does and doesn't do with your data, in a few plain sentences (#18).
struct PrivacySection: View {
    var body: some View {
        Section {
            Label {
                Text(SettingsDataCopy.privacy)
                    .foregroundStyle(Color.brand(\.ink))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "hand.raised")
                    .foregroundStyle(Color.brandText(\.subtext))
                    .accessibilityHidden(true)
            }
        } header: {
            Text(SettingsScreenCopy.paneData)
        }
    }
}

/// Export as CSV or a full backup, and import a backup or a Strong or Hevy export (#18).
struct TransferSections: View {
    /// Whose weight unit a CSV without units is read in. `nil` uses the device's.
    let profile: Profile?
    @Environment(\.modelContext) private var context
    @State private var exported: ExportedFile?
    @State private var showsExporter = false
    @State private var exportResult: LocalizedStringResource?
    @State private var exportFailed = false
    @State private var showsImporter = false
    @State private var report: ImportReport?

    var body: some View {
        Section {
            exportButton(SettingsDataCopy.exportCSV, symbol: "tablecells", kind: .workouts)
            exportButton(SettingsDataCopy.exportBackup, symbol: "archivebox", kind: .backup)
            if let exportResult {
                StatusRow(tone: exportFailed ? .problem : .good, text: exportResult)
            }
        } header: {
            Text(SettingsDataCopy.export)
        } footer: {
            Text(SettingsDataCopy.exportNote)
        }
        .fileExporter(
            isPresented: $showsExporter, document: exported, contentType: exported?.kind.contentType ?? .json,
            defaultFilename: exported?.name
        ) { result in
            if case .success = result { show(export: SettingsDataCopy.exportSaved, failed: false) }
            if case .failure = result { show(export: SettingsDataCopy.exportFailed, failed: true) }
            exported = nil
        }
        Section {
            Button {
                showsImporter = true
            } label: {
                Label {
                    Text(SettingsDataCopy.importFile)
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            if let report {
                ImportReportView(report: report)
            }
        } header: {
            Text(SettingsDataCopy.importTitle)
        } footer: {
            Text(SettingsDataCopy.importNote)
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: ImportKind.contentTypes) { result in
            // Cancelling isn't a failure, and reports nothing.
            if case .success(let url) = result { importFile(at: url) }
        }
    }

    private func exportButton(_ label: LocalizedStringResource, symbol: String, kind: ExportKind) -> some View {
        Button {
            export(kind)
        } label: {
            Label {
                Text(label)
            } icon: {
                Image(systemName: symbol)
            }
        }
    }

    private func export(_ kind: ExportKind) {
        exportResult = nil
        do {
            let data =
                switch kind {
                case .workouts: try DataTransfer.exportCSV(from: context)
                case .backup: try DataTransfer.exportBackup(from: context)
                }
            exported = ExportedFile(kind: kind, data: data)
            showsExporter = true
        } catch {
            show(export: SettingsDataCopy.exportFailed, failed: true)
        }
    }

    private func show(export message: LocalizedStringResource, failed: Bool) {
        exportResult = message
        exportFailed = failed
        AccessibilityNotification.Announcement(String(localized: message)).post()
    }

    private func importFile(at url: URL) {
        do {
            let summary = try DataTransfer.importFile(at: url, into: context, fallbackUnits: Units(profile).weight)
            report = ImportReport(summary)
        } catch {
            report = ImportReport(error)
        }
        if let report { AccessibilityNotification.Announcement(report.spoken).post() }
    }
}

/// The result of an import: a heading with a symbol, then each line.
struct ImportReportView: View {
    let report: ImportReport

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.heading)
                    .brandFont(.label)
                    .foregroundStyle(Color.brand(\.ink))
                ForEach(report.lines.indices, id: \.self) { index in
                    Text(report.lines[index])
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            let tone: StatusRow.Tone = report.succeeded ? .good : .problem
            Image(systemName: tone.symbol)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Delete all data (#18): a destructive button, then a confirmation that names what goes and
/// spells the action out on its own button. Without a profile the app shows onboarding again;
/// `ErasureNotice` reports there how it went.
struct DeleteSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.sessionLink) private var link
    @State private var confirms = false
    @State private var isDeleting = false
    @State private var failed = false

    var body: some View {
        Section {
            Button(role: .destructive) {
                confirms = true
            } label: {
                Label {
                    Text(isDeleting ? SettingsDataCopy.deleting : SettingsDataCopy.deleteAll)
                } icon: {
                    // Red like its words, not the accent color.
                    Image(systemName: "trash")
                        .foregroundStyle(Color.brandText(\.alert))
                }
            }
            .disabled(isDeleting)
            .confirmationDialog(
                Text(SettingsDataCopy.deleteConfirmTitle), isPresented: $confirms, titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    deleteEverything()
                } label: {
                    Text(SettingsDataCopy.deleteConfirm)
                }
                Button(role: .cancel) {
                } label: {
                    Text(SettingsDataCopy.cancel)
                }
            } message: {
                Text(SettingsDataCopy.deleteConfirmMessage)
            }
            if failed {
                StatusRow(tone: .problem, text: SettingsDataCopy.deleteFailed)
            }
            #if os(macOS)
                // The Settings window stays open after the main window goes back to onboarding.
                ErasureNotice()
            #endif
        } header: {
            Text(SettingsDataCopy.deleteTitle)
        } footer: {
            Text(SettingsDataCopy.deleteNote)
        }
    }

    private func deleteEverything() {
        let container = context.container
        let link = link
        isDeleting = true
        failed = false
        // Not tied to this view, which goes away as soon as the profile is deleted.
        Task { @MainActor in
            do {
                try await DataEraser.eraseEverything(in: container, link: link)
            } catch {
                failed = true
                AccessibilityNotification.Announcement(String(localized: SettingsDataCopy.deleteFailed)).post()
            }
            isDeleting = false
        }
    }
}

#Preview {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    return Form {
        PrivacySection()
        TransferSections(profile: nil)
        DeleteSection()
        Section {
            ImportReportView(report: ImportReport(DataTransferError.unrecognizedCSV))
        }
    }
    .modelContainer(container)
}
