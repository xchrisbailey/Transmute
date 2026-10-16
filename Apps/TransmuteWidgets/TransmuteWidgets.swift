import SwiftUI
import WidgetKit

@main
struct TransmuteWidgets: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
        TodayWidget()
        BeginWorkoutControl()
    }
}
