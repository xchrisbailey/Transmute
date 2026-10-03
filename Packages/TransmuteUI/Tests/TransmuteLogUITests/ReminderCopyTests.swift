import Foundation
import Testing
import TransmuteCore

@testable import TransmuteLogUI

struct ReminderCopyTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    nonisolated(unsafe) static let catalog: [String: Any] = {
        let url = repo.appending(path: "Apps/Shared/Localizable.xcstrings")
        let json = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        return (json as? [String: Any])?["strings"] as? [String: Any] ?? [:]
    }()

    static let resources: [LocalizedStringResource] = [
        ReminderCopy.title, ReminderCopy.trainingDay, ReminderCopy.trainingDayDetail, ReminderCopy.time,
        ReminderCopy.missedDay, ReminderCopy.missedDayDetail, ReminderCopy.footer, ReminderCopy.denied,
        ReminderCopy.openSettings, ReminderCopy.trainingDayTitle("Lower A"), ReminderCopy.trainingDayUntitled,
        ReminderCopy.trainingDayBody, ReminderCopy.missedDayTitle, ReminderCopy.missedDayBody,
    ]

    @Test(arguments: resources)
    func copyIsPlainAndInTheCatalog(_ resource: LocalizedStringResource) throws {
        #expect(resource.key.hasPrefix("plain.reminders."))
        let entry = try #require(Self.catalog[resource.key] as? [String: Any], "\(resource.key) missing")
        #expect((entry["comment"] as? String)?.hasPrefix("plain.") == true)
    }

    @Test func trainingDayNotificationNamesTheSession() {
        let named = PlannedReminder(id: "a", kind: .trainingDay, fireDate: .now, sessionName: "Lower A")
        #expect(ReminderScheduler.content(for: named).title.contains("Lower A"))
        let unnamed = PlannedReminder(id: "b", kind: .trainingDay, fireDate: .now, sessionName: "")
        #expect(!ReminderScheduler.content(for: unnamed).title.isEmpty)
        #expect(!ReminderScheduler.content(for: unnamed).body.isEmpty)
    }

    @Test func theNudgeDoesNotNameWhatWasMissed() {
        let nudge = PlannedReminder(id: "c", kind: .missedDay, fireDate: .now, sessionName: "Lower A")
        let content = ReminderScheduler.content(for: nudge)
        #expect(!content.title.isEmpty)
        for text in [content.title, content.body] {
            #expect(!text.contains("Lower A"))
            #expect(!text.localizedCaseInsensitiveContains("missed"))
        }
    }
}
