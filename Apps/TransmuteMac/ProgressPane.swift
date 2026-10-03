import SwiftUI
import TransmuteUI

/// Where the progress charts go (#16). Until they land this is the empty state.
struct ProgressPane: View {
    var body: some View {
        ContentUnavailableView {
            Image(systemName: "flask")
                .foregroundStyle(Color.brand(\.magic))
        } description: {
            Text(Copy.emptyLog)
                .brandFont(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brand(\.base))
        .navigationTitle(Text(MacCopy.progress))
    }
}
