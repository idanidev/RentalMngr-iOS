import SwiftUI

/// Rich property card for wide layouts (Mac / iPad grids): a mini-dashboard
/// (occupancy bar, income, tenants, vacancies) plus a per-room breakdown
/// (name, tenant, rent, occupied/free). Pure presentation — wrap it in a
/// Button or NavigationLink at the call site.
struct PropertyRichCard: View {
    @Environment(\.horizontalSizeClass) private var hSize
    let property: Property

    private var privateRooms: [Room] { property.privateRooms }
    private var occupiedCount: Int { property.occupiedPrivateRooms.count }
    private var totalCount: Int { privateRooms.count }
    private var vacantCount: Int { property.vacantPrivateRooms.count }
    private var occupancy: Double { property.occupancyRate }

    private var occupancyColor: Color {
        occupancy >= 80 ? .green : (occupancy >= 50 ? .orange : .red)
    }

    private var commonCount: Int { property.commonRooms.count }
    private var totalSqm: Int {
        let sum = (property.rooms ?? []).compactMap(\.sizeSqm).reduce(Decimal.zero, +)
        return NSDecimalNumber(decimal: sum).intValue
    }

    private func sqmLabel(_ value: Decimal?) -> String? {
        guard let value, value > 0 else { return nil }
        return "\(NSDecimalNumber(decimal: value).intValue) m²"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if totalCount > 0 {
                occupancyBar
            }
            statsRow
            if !privateRooms.isEmpty {
                Divider()
                roomBreakdown
            }
            if commonCount > 0 || totalSqm > 0 {
                footer
            }
        }
        .padding(hSize == .regular ? 20 : 16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .macCardHover()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.18), .purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 46, height: 46)
                Image(systemName: "building.2.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .font(hSize == .regular ? .title3.bold() : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(property.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if totalCount > 0 {
                Text(String(format: "%.0f%%", occupancy))
                    .font(.subheadline.bold())
                    .foregroundStyle(occupancyColor)
            }
        }
    }

    // MARK: - Occupancy bar

    private var occupancyBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(occupancyColor)
                        .frame(width: geo.size.width * min(CGFloat(occupancy / 100), 1))
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Label(
                    "\(occupiedCount)/\(totalCount) hab.",
                    systemImage: "bed.double.fill"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                if vacantCount > 0 {
                    Text("\(vacantCount) libres")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: property.monthlyRevenue.formatted(currencyCode: "EUR"),
                label: "/ mes",
                color: .mint
            )
            statDivider
            statItem(
                value: "\(occupiedCount)",
                label: "Inquilinos",
                color: .primary
            )
            statDivider
            statItem(
                value: "\(vacantCount)",
                label: "Libres",
                color: vacantCount > 0 ? .orange : .primary
            )
        }
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(hSize == .regular
                    ? .system(.title3, design: .rounded, weight: .bold)
                    : .system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 26)
    }

    // MARK: - Room breakdown

    private var roomBreakdown: some View {
        VStack(spacing: 9) {
            ForEach(privateRooms) { room in
                roomRow(room)
            }
        }
    }

    @ViewBuilder
    private func roomRow(_ room: Room) -> some View {
        let statusText = room.occupied ? (room.tenantName ?? "Ocupada") : "Libre"
        let statusColor: Color = room.occupied ? .secondary : .orange
        let rent = room.monthlyRent.formatted(currencyCode: "EUR")
        let sqm = sqmLabel(room.sizeSqm)

        // Progressively drops m² then the status text as the card narrows.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                statusDot(room)
                Text(room.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                Spacer(minLength: 8)
                Text(statusText).font(.caption).foregroundStyle(statusColor).lineLimit(1)
                if let sqm {
                    Text(sqm).font(.caption2).foregroundStyle(.tertiary)
                }
                Text(rent).font(.caption.weight(.semibold)).foregroundStyle(.mint)
                    .frame(minWidth: 52, alignment: .trailing)
            }
            .contentShape(Rectangle())
            HStack(spacing: 10) {
                statusDot(room)
                Text(room.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                Spacer(minLength: 8)
                Text(statusText).font(.caption).foregroundStyle(statusColor).lineLimit(1)
                Text(rent).font(.caption.weight(.semibold)).foregroundStyle(.mint)
            }
            .contentShape(Rectangle())
            HStack(spacing: 10) {
                statusDot(room)
                Text(room.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                Spacer(minLength: 8)
                Text(rent).font(.caption.weight(.semibold)).foregroundStyle(.mint)
            }
            .contentShape(Rectangle())
        }
    }

    private func statusDot(_ room: Room) -> some View {
        Circle()
            .fill(room.occupied ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 8, height: 8)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if commonCount > 0 {
                Label("\(commonCount) comunes", systemImage: "sofa.fill")
            }
            if totalSqm > 0 {
                Label("\(totalSqm) m²", systemImage: "ruler")
            }
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }
}
