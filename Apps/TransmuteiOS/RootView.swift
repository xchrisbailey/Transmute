import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Onboarding until there's a profile, then the app.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    var body: some View {
        if let profile = profiles.first {
            NavigationStack {
                PlaceholderRoot(platform: "iPhone")
                    .toolbar {
                        NavigationLink {
                            ProfileView(profile: profile)
                        } label: {
                            Label {
                                Text(ProfileCopy.profile)
                            } icon: {
                                Image(systemName: "person.crop.circle")
                            }
                        }
                    }
            }
        } else {
            OnboardingFlow { _, _ in }
        }
    }
}
