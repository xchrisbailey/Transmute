import SwiftUI
import WidgetKit

/// Transmute on the Mac desktop and in Notification Centre (#19).
@main
struct TransmuteMacWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
