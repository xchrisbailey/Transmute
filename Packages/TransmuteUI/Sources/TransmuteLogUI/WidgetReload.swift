import SwiftData
import SwiftUI
import WidgetKit

extension View {
    /// Keeps the widgets current (#19). They read the store from disk, so their timelines are
    /// reloaded each time it's saved: when a workout starts, a set is logged, a workout
    /// finishes or the plan changes. Leaving the foreground reloads them once more, for
    /// anything that synced in from another device meanwhile.
    public func reloadsWidgets() -> some View {
        modifier(WidgetReload())
    }
}

private struct WidgetReload: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
    }
}
