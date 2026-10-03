import SwiftUI
import WidgetKit

/// Transmute on the watch face and in the Smart Stack (#15, #19).
@main
struct TransmuteWatchWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WeekWidget()
    }
}
