import AppIntents
import SwiftUI
import TransmuteCore
import WidgetKit

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
