import SwiftUI
import TransmuteCore
import TransmuteLogUI
import TransmuteUI

/// The four places in the Mac window, in sidebar order. The symbols match the iPhone's tabs.
enum SidebarSection: String, CaseIterable, Identifiable {
    case today, plan, log, progress

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .today: LogCopy.today
        case .plan: LogCopy.plan
        case .log: HistoryCopy.title
        case .progress: MacCopy.progress
        }
    }

    var symbol: String {
        switch self {
        case .today: "flame"
        case .plan: "calendar"
        case .log: "list.bullet.rectangle"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }

    /// ⌘1 to ⌘4, in sidebar order.
    var shortcut: KeyEquivalent {
        switch self {
        case .today: "1"
        case .plan: "2"
        case .log: "3"
        case .progress: "4"
        }
    }
}

/// The sidebar (#17): the four sections, then the streak and the profile at the bottom.
struct SidebarView: View {
    @Binding var section: SidebarSection
    let profile: Profile
    /// Weeks in the current streak. `nil` hides the line.
    let streakWeeks: Int?
    let onProfile: () -> Void

    /// A list selection can be empty; the window always shows a section.
    private var selection: Binding<SidebarSection?> {
        Binding {
            section
        } set: {
            section = $0 ?? section
        }
    }

    var body: some View {
        List(selection: selection) {
            ForEach(SidebarSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbol)
                }
                .tag(section)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                if let streakWeeks {
                    Label {
                        Text(Copy.streak(weeks: streakWeeks))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.now))
                }
                Divider()
                ProfileFooter(profile: profile, action: onProfile)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

/// Who's training: name, latest bodyweight in their units and days a week. Opens the profile.
private struct ProfileFooter: View {
    let profile: Profile
    let action: () -> Void

    /// The profile has no name of its own, so this is the Mac account's.
    private var name: String {
        let name = NSFullUserName()
        return name.isEmpty ? String(localized: ProfileCopy.profile) : name
    }

    private var detail: String {
        let units = Units(system: profile.unitSystem)
        let days = String(localized: MacCopy.daysPerWeek(profile.schedule.daysPerWeek))
        guard let kg = profile.latestBodyweightKg else { return days }
        return "\(units.formatWeight(kg: kg)) · \(days)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(Color.brandText(\.subtext))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name)
                        .brandFont(.label)
                        .foregroundStyle(Color.brand(\.ink))
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(ProfileCopy.profile))
    }
}
