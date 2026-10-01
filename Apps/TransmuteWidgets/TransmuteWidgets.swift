import SwiftUI
import WidgetKit

/// Everything Transmute shows outside the app. For now, the workout's Live Activity (#11);
/// home screen widgets come with #19.
@main
struct TransmuteWidgets: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
    }
}
