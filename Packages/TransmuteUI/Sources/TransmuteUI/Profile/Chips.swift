#if !os(watchOS)
    import SwiftUI

    /// A toggle shown as a pill. Selection is shown with a checkmark as well as colour (#22).
    struct Chip: View {
        let label: LocalizedStringResource
        @Binding var isOn: Bool

        var body: some View {
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    if isOn {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .brandFont(.label)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundStyle(isOn ? Color.brand(\.base) : Color.brand(\.ink))
                .background(isOn ? Color.brand(\.magic) : Color.brand(\.surface0), in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? [.isSelected] : [])
        }
    }

    /// Chips that wrap onto as many lines as they need, so large text reflows instead of
    /// truncating.
    struct ChipFlow<Item: Hashable, Content: View>: View {
        let items: [Item]
        @ViewBuilder let content: (Item) -> Content

        var body: some View {
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self, content: content)
            }
        }
    }

    struct FlowLayout: Layout {
        var spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
            let height = rows.last.map { $0.y + $0.height } ?? 0
            let width = rows.map(\.width).max() ?? 0
            return CGSize(width: proposal.width ?? width, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            for row in arrange(width: bounds.width, subviews: subviews) {
                var x = bounds.minX
                for index in row.indices {
                    let size = subviews[index].sizeThatFits(.init(width: bounds.width, height: nil))
                    subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .init(size))
                    x += size.width + spacing
                }
            }
        }

        private struct Row {
            var indices: [Int] = []
            var y: CGFloat = 0
            var width: CGFloat = 0
            var height: CGFloat = 0
        }

        private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
            var rows = [Row()]
            for index in subviews.indices {
                let size = subviews[index].sizeThatFits(.init(width: width, height: nil))
                var row = rows[rows.count - 1]
                if !row.indices.isEmpty, row.width + spacing + size.width > width {
                    let y = row.y + row.height + spacing
                    rows.append(Row(y: y))
                    row = rows[rows.count - 1]
                }
                row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
                row.height = max(row.height, size.height)
                row.indices.append(index)
                rows[rows.count - 1] = row
            }
            return rows
        }
    }
#endif
