import SwiftUI

struct InventoryItemRow: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder or specific icon based on name analysis could go here
            Image(systemName: "cube.box")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Condition Chip
                Text(item.condition.label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.condition.color.opacity(0.15))
                    .foregroundColor(item.condition.color)
                    .clipShape(Capsule())

                if let price = item.purchasePrice {
                    Text(price.formatted(currencyCode: nil))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
