import SwiftUI
import WidgetKit

/// Everything Transmute shows outside the app: the workout's Live Activity (#11), Today on
/// the Home Screen and the Lock Screen, and a button for Control Center (#19).
@main
struct TransmuteWidgets: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
        TodayWidget()
        BeginWorkoutControl()
    }
}
