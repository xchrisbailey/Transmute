import AppIntents
import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// "What's my workout today?" (#19): answered without opening the app, from the same glance
/// the widgets draw.
struct TodayWorkoutIntent: AppIntent {
    static let title = LocalizedStringResource(
        "plain.shortcut.today.title", defaultValue: "What's my workout today?",
        comment: "plain. Shortcut that says today's session.")
    static let description = IntentDescription(
        LocalizedStringResource(
            "plain.shortcut.today.description",
            defaultValue: "Says today's session, its first lift and how this week is going.",
            comment: "plain. Describes the What's my workout today? shortcut in the Shortcuts app."))

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let glance = (try? TodayGlance.load(from: TransmuteStore.shared.mainContext)) ?? TodayGlance()
        return .result(dialog: IntentDialog(stringLiteral: ShortcutCopy.today(glance))) {
            TodaySnippet(glance: glance)
        }
    }
}

/// The answer drawn under Siri's words: the day, the lift in figures, and the week. System
/// fonts, since a snippet is drawn outside the app.
struct TodaySnippet: View {
    let glance: TodayGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: ShortcutCopy.title(glance))
                    .font(.headline)
                Spacer()
                if let status = ShortcutCopy.status(glance) {
                    Text(status)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if let lift = glance.nextLift, !glance.isDone {
                Text(verbatim: lift.text)
                    .font(.subheadline.monospacedDigit())
            }
            if let week = ShortcutCopy.weekFigure(glance.week) {
                Text(verbatim: week)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    TodaySnippet(
        glance: TodayGlance(
            day: .session("Lower A"),
            nextLift: .init(name: "Bench press", sets: 5, amount: "5", load: "80 kg"),
            week: .init(done: 1, planned: 3)))
}
