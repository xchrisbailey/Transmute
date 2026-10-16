import SwiftData
import SwiftUI
import WidgetKit

/// Keeps the widgets current. They read the store from disk, so their timelines are reloaded
/// each time the app process saves it: when a workout starts, a set is logged, a workout
/// finishes, the plan changes or a Shortcut logs a bodyweight.
public enum WidgetReload {
    /// Starts reloading every timeline after each save. Call it once from an `App`'s `init`, so
    /// it's listening before an App Intent that launched the process in the background saves.
    /// Not part of `TransmuteStore.makeContainer`, which the widget extensions call too.
    @MainActor
    public static func listen() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @MainActor private static var observer: NSObjectProtocol?
}

extension View {
    /// Reloads the widgets when the app leaves the foreground. This is the only thing that
    /// covers data that synced in from another device, which no local save sees.
    public func reloadsWidgetsOnLeavingForeground() -> some View {
        modifier(WidgetReloadOnLeavingForeground())
    }
}

private struct WidgetReloadOnLeavingForeground: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
    }
}
