import AppIntents
import SwiftData
import TransmuteCore
import TransmuteUI
import WidgetKit

/// "Log bodyweight" (#19): stores a weight on the profile without opening the app. It's
/// written to Health as well when the person already allowed that; a shortcut never asks.
struct LogBodyweightIntent: AppIntent {
    static let title = LocalizedStringResource(
        "plain.shortcut.weight.title", defaultValue: "Log bodyweight",
        comment: "plain. Shortcut that stores a bodyweight.")
    static let description = IntentDescription(
        LocalizedStringResource(
            "plain.shortcut.weight.description", defaultValue: "Adds a bodyweight to your Transmute profile.",
            comment: "plain. Describes the Log bodyweight shortcut in the Shortcuts app."))

    /// Asked for when missing, in the unit the device's region uses.
    @Parameter(
        title: LocalizedStringResource(
            "plain.shortcut.weight.parameter", defaultValue: "Weight",
            comment: "plain. Name of the Log bodyweight shortcut's weight field."),
        defaultUnit: .kilograms, defaultUnitAdjustForLocale: true, supportsNegativeNumbers: false,
        requestValueDialog: IntentDialog(
            LocalizedStringResource(
                "plain.shortcut.weight.ask", defaultValue: "What's your weight?",
                comment: "plain. Siri asks for the bodyweight to log.")))
    var weight: Measurement<UnitMass>

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$weight) as bodyweight", table: "AppShortcuts")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard BodyweightLog.plausibleKg.contains(BodyweightLog.kilograms(weight)) else {
            throw $weight.needsValueError(IntentDialog(ShortcutCopy.askWeightAgain))
        }
        let context = TransmuteStore.shared.mainContext
        let entry: BodyweightEntry
        do {
            guard let added = try BodyweightLog.add(weight, in: context) else {
                return .result(dialog: IntentDialog(ShortcutCopy.weightNeedsProfile))
            }
            entry = added
        } catch {
            return .result(dialog: IntentDialog(ShortcutCopy.weightFailed))
        }
        let inHealth = await saveToHealth(entry, in: context)
        // The app may not have a window to notice the save.
        WidgetCenter.shared.reloadAllTimelines()
        let spoken = BodyweightLog.spoken(kg: entry.kg, units: Units(system: entry.profile?.unitSystem))
        return .result(dialog: IntentDialog(ShortcutCopy.logged(spoken, inHealth: inHealth)))
    }

    /// Writes the entry to Health when that's already allowed, and keeps the sample's id on
    /// it so importing never brings it back as a duplicate. The Mac has no Health.
    @MainActor
    private func saveToHealth(_ entry: BodyweightEntry, in context: ModelContext) async -> Bool {
        #if os(iOS) || os(watchOS)
            let health = HealthKitService()
            guard health.canSaveBodyweight,
                let id = try? await health.saveBodyweight(kg: entry.kg, at: entry.date)
            else { return false }
            entry.healthKitSampleID = id
            try? context.save()
            return true
        #else
            return false
        #endif
    }
}
