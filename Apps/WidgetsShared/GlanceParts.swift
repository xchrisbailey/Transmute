import SwiftUI
import TransmuteCore
import TransmuteUI
import WidgetKit

/// The mark. On tinted faces and Home Screens it's desaturated and takes the tint, so it
/// needs no template copy.
struct WidgetMark: View {
    var body: some View {
        Image("Mark")
            .resizable()
            .widgetAccentedRenderingMode(.accentedDesaturated)
            .scaledToFit()
    }
}

/// This week's sessions as a row of pills: filled for a session done, an outline for one
/// still to do, so the count reads without colour. Sits beside the figure, never alone.
struct WeekPills: View {
    let week: TodayGlance.Week
    var height: CGFloat = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(week.planned, 0), id: \.self) { index in
                if index < week.done {
                    Capsule()
                        .fill(Color.brand(\.done))
                        .widgetAccentable()
                } else {
                    Capsule()
                        .strokeBorder(Color.brand(\.overlay1), lineWidth: 1)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The streak: a flame, peach where there's colour, then the weeks, with the figure in
/// Geist Mono.
struct StreakLabel: View {
    let weeks: Int
    /// "3 wk" rather than "3 weeks in a row".
    var isShort = false
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: size - 1))
                .foregroundStyle(Color.brand(\.now))
                .widgetAccentable()
            Text(text)
                .font(.system(size: size))
                .monospacedDigit()
        }
        .lineLimit(1)
    }

    /// The words as the catalog orders them, with the number picked out for the brand font.
    private var text: AttributedString {
        let words = String(localized: isShort ? GlanceCopy.streakShort(weeks: weeks) : GlanceCopy.streak(weeks: weeks))
        var text = AttributedString(words)
        if let figure = text.range(of: weeks.formatted()) {
            text[figure].font = .brandNumber(size: size, relativeTo: .caption)
        }
        return text
    }
}

extension TodayGlance {
    /// No plan, and no workout going: there's only the app to point at.
    var isEmpty: Bool {
        day == .nothingPlanned && !isRunning
    }

    /// There's a session today that hasn't been started.
    var isToDo: Bool {
        sessionName != nil && !isDone && !isRunning
    }

    /// For the widget gallery, placeholders and previews.
    static let sample = TodayGlance(
        day: .session("Lower A"),
        nextLift: NextLift(
            name: "Bench press", sets: 5, amount: "5", load: "80 kg", spokenAmount: "5", spokenLoad: "80 kilograms"),
        streakWeeks: 3, week: Week(done: 1, planned: 3))
}
