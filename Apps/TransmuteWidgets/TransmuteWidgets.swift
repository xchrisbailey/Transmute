import SwiftUI
import WidgetKit

/// Everything Transmute shows outside the app: the workout's Live Activity (#11), and Today
/// on the Home Screen and the Lock Screen (#19).
@main
struct TransmuteWidgets: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
        TodayWidget()
    }
}
