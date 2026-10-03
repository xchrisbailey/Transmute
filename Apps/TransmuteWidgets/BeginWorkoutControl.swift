import AppIntents
import SwiftUI
import TransmuteCore
import WidgetKit

/// A button for Control Center, the Lock Screen and the Action button (#19): it runs Begin
/// today's workout, which opens the app and starts the session.
struct BeginWorkoutControl: ControlWidget {
    static let kind = "\(Transmute.bundlePrefix).control.begin"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: BeginWorkoutIntent()) {
                Label {
                    Text(GlanceCopy.beginWorkout)
                } icon: {
                    Image(systemName: "flame")
                }
            }
        }
        .displayName(GlanceCopy.beginWorkout)
        .description(GlanceCopy.beginWorkoutDescription)
    }
}
