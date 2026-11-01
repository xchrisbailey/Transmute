import SwiftUI

/// A `List` in the brand: `base` behind it and `mantle` cards for its rows. Without it rows take
/// the system grey (Mocha) or white (Latte).
///
/// The row colour is set on the content, because `.listRowBackground` on the `List` itself does
/// nothing. A row that sets its own, such as a button on `Color.clear`, keeps it.
public struct BrandList<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        List {
            Group { content }
                .listRowBackground(Color.brand(\.mantle))
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
    }
}

/// A `Form` in the brand. See `BrandList`.
public struct BrandForm<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        Form {
            Group { content }
                .listRowBackground(Color.brand(\.mantle))
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
    }
}
