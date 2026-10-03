import SwiftUI
import TransmuteUI

/// What the menu bar can ask the front window to do. The window publishes this as a focused
/// scene value; with no window, or during onboarding, there is none and the commands are off.
struct WindowActions {
    /// The section the window is showing.
    var section: SidebarSection
    var show: (SidebarSection) -> Void
    /// Starts today's session if there is one to do, otherwise a workout off the plan.
    var newWorkout: () -> Void
    /// Goes to Plan: the brew screen without a plan, the rebrew sheet with one.
    var brewPlan: () -> Void
    /// Puts the cursor in the log's search field.
    var findInLog: () -> Void
}

extension FocusedValues {
    @Entry var windowActions: WindowActions?
}

/// Menu bar commands and their shortcuts (#17): ⌘N New Workout, ⌘B Brew a plan, ⌘F Find in
/// Log, and ⌘1 to ⌘4 for the sidebar sections.
struct TransmuteCommands: Commands {
    @FocusedValue(\.windowActions) private var window

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                window?.newWorkout()
            } label: {
                Text(MacCopy.newWorkout)
            }
            .keyboardShortcut("n")
            .disabled(window == nil)
            Button {
                window?.brewPlan()
            } label: {
                Text(Copy.brewPlan)
            }
            .keyboardShortcut("b")
            .disabled(window == nil)
        }
        CommandGroup(after: .textEditing) {
            Button {
                window?.findInLog()
            } label: {
                Text(MacCopy.findInLog)
            }
            .keyboardShortcut("f")
            .disabled(window?.section != .log)
        }
        CommandGroup(before: .sidebar) {
            ForEach(SidebarSection.allCases) { section in
                Button {
                    window?.show(section)
                } label: {
                    Text(section.title)
                }
                .keyboardShortcut(section.shortcut)
                .disabled(window == nil)
            }
            Divider()
        }
        SidebarCommands()
        InspectorCommands()
    }
}
