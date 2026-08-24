import SwiftUI

/// Self-contained marketing screen mockups for App Store screenshots.
/// Each screen uses hardcoded sample data (NO prices) and zero backend.
/// Activate by launching with env var `MOCKUP_SCREEN=dashboard|properties|rooms|tenants|alerts`.
enum MockupShowcase {
    enum Screen: String {
        case dashboard
        case properties
        case rooms
        case tenants
        case alerts
    }
}

struct MockupShowcaseView: View {
    let screen: MockupShowcase.Screen

    var body: some View {
        switch screen {
        case .dashboard:  MockupDashboard()
        case .properties: MockupProperties()
        case .rooms:      MockupRooms()
        case .tenants:    MockupTenants()
        case .alerts:     MockupAlerts()
        }
    }
}

// MARK: - 1. Dashboard

private struct MockupDashboard: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MockupTopBar(title: MockupL10n.t("Inicio"), badge: 4)

                // Greeting card
                VStack(alignment: .leading, spacing: 6) {
                    Text(MockupL10n.t("Buenos días, Daniel"))
                        .font(.largeTitle.bold())
                    Text(MockupL10n.t("Esto es lo importante hoy"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Quick stats — 2x2 grid (no money values)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    MockStatCard(icon: "building.2.fill", label: MockupL10n.t("Propiedades"), value: "3", tint: .orange)
                    MockStatCard(icon: "bed.double.fill", label: MockupL10n.t("Habitaciones"), value: "8", tint: .blue)
                    MockStatCard(icon: "person.2.fill", label: MockupL10n.t("Ocupadas"), value: "7 / 8", tint: .purple)
                    MockStatCard(icon: "calendar.badge.clock", label: MockupL10n.t("Vencen pronto"), value: "2", tint: .red)
                }
                .padding(.horizontal, 20)

                // Activity card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(MockupL10n.t("Actividad reciente"))
                            .font(.headline)
                        Spacer()
                        Text(MockupL10n.t("Esta semana"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    ActivityRow(icon: "doc.text.fill", tint: .blue, title: MockupL10n.t("Nuevo contrato firmado"), subtitle: MockupL10n.t("Marta · Habitación 2 · Calle Mayor"))
                    ActivityRow(icon: "checkmark.seal.fill", tint: .green, title: MockupL10n.t("Renta de mayo cobrada"), subtitle: MockupL10n.t("Carlos · Habitación 1"))
                    ActivityRow(icon: "person.crop.circle.badge.plus", tint: .purple, title: MockupL10n.t("Nuevo inquilino registrado"), subtitle: MockupL10n.t("Laura entra el 1 de junio"))
                    ActivityRow(icon: "wrench.adjustable.fill", tint: .orange, title: MockupL10n.t("Mantenimiento programado"), subtitle: MockupL10n.t("Calefactor · Calle del Sol"))
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 2. Properties list

private struct MockupProperties: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MockupTopBar(title: MockupL10n.t("Propiedades"), badge: nil, trailing: "plus")

                VStack(spacing: 14) {
                    PropertyCard(
                        name: "Calle Mayor 12",
                        location: "Madrid · Centro",
                        rooms: 4,
                        occupancy: 1.0,
                        emoji: "🏛️"
                    )
                    PropertyCard(
                        name: "Calle del Sol 5",
                        location: "Madrid · Malasaña",
                        rooms: 3,
                        occupancy: 0.67,
                        emoji: "🌇"
                    )
                    PropertyCard(
                        name: "Avenida del Mar 28",
                        location: "Valencia · Cabanyal",
                        rooms: 1,
                        occupancy: 1.0,
                        emoji: "🌊"
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 3. Property detail — rooms

private struct MockupRooms: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MockupTopBar(title: "Calle Mayor 12", badge: nil, backArrow: true)

                // Hero
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calle Mayor 12")
                        .font(.largeTitle.bold())
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Madrid · Centro")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                // Tab bar
                HStack(spacing: 22) {
                    TabPill(label: MockupL10n.t("Habitaciones"), active: true)
                    TabPill(label: MockupL10n.t("Inquilinos"), active: false)
                    TabPill(label: MockupL10n.t("Finanzas"), active: false)
                    TabPill(label: MockupL10n.t("Documentos"), active: false)
                }
                .padding(.horizontal, 20)

                // Rooms grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    RoomCard(name: MockupL10n.t("Habitación 1"), tenant: "Carlos M.", status: .occupied, color: .blue)
                    RoomCard(name: MockupL10n.t("Habitación 2"), tenant: "Marta L.", status: .occupied, color: .purple)
                    RoomCard(name: MockupL10n.t("Habitación 3"), tenant: "Laura R.", status: .startingSoon, color: .orange)
                    RoomCard(name: MockupL10n.t("Habitación 4"), tenant: nil, status: .available, color: .green)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 4. Tenants & contracts

private struct MockupTenants: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MockupTopBar(title: MockupL10n.t("Inquilinos"), badge: nil, trailing: "magnifyingglass")

                VStack(spacing: 12) {
                    TenantRow(initials: "CM", name: "Carlos Méndez", room: MockupL10n.t("Habitación 1 · Calle Mayor"), status: .active, endDate: MockupL10n.t("Renueva 14 ago"))
                    TenantRow(initials: "ML", name: "Marta López", room: MockupL10n.t("Habitación 2 · Calle Mayor"), status: .active, endDate: MockupL10n.t("Renueva 30 sep"))
                    TenantRow(initials: "LR", name: "Laura Ruiz", room: MockupL10n.t("Habitación 3 · Calle Mayor"), status: .startingSoon, endDate: MockupL10n.t("Entra 1 jun"))
                    TenantRow(initials: "AF", name: "Andrés Fernández", room: MockupL10n.t("Habitación 1 · Calle del Sol"), status: .expiringSoon, endDate: MockupL10n.t("Vence en 18 días"))
                    TenantRow(initials: "PG", name: "Paula Giménez", room: MockupL10n.t("Habitación 2 · Calle del Sol"), status: .active, endDate: MockupL10n.t("Renueva 12 nov"))
                    TenantRow(initials: "RB", name: "Roberto Bermejo", room: "Avenida del Mar 28", status: .active, endDate: MockupL10n.t("Renueva 5 mar"))
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 5. Alerts & reminders

private struct MockupAlerts: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MockupTopBar(title: MockupL10n.t("Avisos"), badge: nil)

                VStack(alignment: .leading, spacing: 4) {
                    Text(MockupL10n.t("Siempre un paso por delante"))
                        .font(.title3.bold())
                    Text(MockupL10n.t("Nunca pierdas un contrato ni una fecha clave"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    AlertCard(
                        icon: "exclamationmark.triangle.fill",
                        tint: .red,
                        title: MockupL10n.t("Contrato vence en 18 días"),
                        subtitle: "Andrés Fernández · Calle del Sol 5",
                        cta: MockupL10n.t("Renovar")
                    )
                    AlertCard(
                        icon: "calendar.badge.exclamationmark",
                        tint: .orange,
                        title: MockupL10n.t("Renovación en 30 días"),
                        subtitle: "Carlos Méndez · Calle Mayor 12",
                        cta: MockupL10n.t("Preparar")
                    )
                    AlertCard(
                        icon: "person.crop.circle.badge.plus",
                        tint: .purple,
                        title: MockupL10n.t("Nuevo inquilino entra el 1 de junio"),
                        subtitle: MockupL10n.t("Laura Ruiz · Habitación 3"),
                        cta: MockupL10n.t("Ver detalles")
                    )
                    AlertCard(
                        icon: "envelope.badge.fill",
                        tint: .blue,
                        title: MockupL10n.t("Invitación pendiente"),
                        subtitle: MockupL10n.t("María quiere compartir 'Calle del Sol'"),
                        cta: MockupL10n.t("Aceptar")
                    )
                    AlertCard(
                        icon: "doc.text.magnifyingglass",
                        tint: .green,
                        title: MockupL10n.t("Resumen semanal listo"),
                        subtitle: MockupL10n.t("5 movimientos · 2 renovaciones esta semana"),
                        cta: MockupL10n.t("Ver")
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Shared mock components

private struct MockupTopBar: View {
    let title: String
    let badge: Int?
    var trailing: String? = nil
    var backArrow: Bool = false

    var body: some View {
        HStack {
            if backArrow {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let badge {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(.red, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
            if let trailing {
                Image(systemName: trailing)
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct MockStatCard: View {
    let icon: String, label: String, value: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 16, weight: .semibold))
            }
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActivityRow: View {
    let icon: String; let tint: Color; let title: String; let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct PropertyCard: View {
    let name: String; let location: String; let rooms: Int; let occupancy: Double; let emoji: String
    private var pct: Int { Int((occupancy * 100).rounded()) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline)
                    Text(location).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            HStack(spacing: 14) {
                Label("\(rooms) hab.", systemImage: "bed.double.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label("\(pct)% ocupación", systemImage: "person.2.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 6)
                    Capsule().fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * occupancy, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct TabPill: View {
    let label: String; let active: Bool
    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.subheadline.weight(active ? .semibold : .regular))
                .foregroundStyle(active ? .primary : .secondary)
            Capsule().fill(active ? Color.accentColor : Color.clear).frame(height: 2)
        }
    }
}

private struct RoomCard: View {
    enum Status { case occupied, available, startingSoon }
    let name: String; let tenant: String?; let status: Status; let color: Color

    var statusLabel: (String, Color) {
        switch status {
        case .occupied:     (MockupL10n.t("Ocupada"), .blue)
        case .available:    (MockupL10n.t("Disponible"), .green)
        case .startingSoon: (MockupL10n.t("Entra pronto"), .orange)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [color.opacity(0.45), color.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 110)
                .overlay(
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(color)
                        .opacity(0.7)
                )
            Text(name).font(.subheadline.bold())
            HStack(spacing: 6) {
                Circle().fill(statusLabel.1).frame(width: 8, height: 8)
                Text(tenant ?? statusLabel.0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TenantRow: View {
    enum Status { case active, expiringSoon, startingSoon }
    let initials: String; let name: String; let room: String; let status: Status; let endDate: String

    var statusBadge: (String, Color, String) {
        switch status {
        case .active:        (MockupL10n.t("Activo"), .green, "checkmark.seal.fill")
        case .expiringSoon:  (MockupL10n.t("Vence pronto"), .orange, "clock.badge.exclamationmark.fill")
        case .startingSoon:  (MockupL10n.t("Entra pronto"), .blue, "person.crop.circle.badge.plus")
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Text(initials).font(.subheadline.bold()).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.bold())
                Text(room).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: statusBadge.2)
                        .foregroundStyle(statusBadge.1)
                        .font(.caption2)
                    Text(endDate).font(.caption2).foregroundStyle(statusBadge.1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AlertCard: View {
    let icon: String; let tint: Color; let title: String; let subtitle: String; let cta: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(cta)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}


/// Marketing-only strings for the App Store screenshot screens.
///
/// Deliberately kept OUT of the app's Localizable.xcstrings: these are fake
/// sample values that exist to fill a screenshot, not product copy, and mixing
/// them into the real catalog would pollute it. Switch the language of a
/// capture with the launch env var `MOCKUP_LANG=en`.
enum MockupL10n {
    private static let isEnglish =
        ProcessInfo.processInfo.environment["MOCKUP_LANG"]?.lowercased().hasPrefix("en") == true

    private static let english: [String: String] = [
        "Inicio": "Home",
        "Buenos días, Daniel": "Good morning, Daniel",
        "Esto es lo importante hoy": "Here's what matters today",
        "Propiedades": "Properties",
        "Habitaciones": "Rooms",
        "Ocupadas": "Occupied",
        "Vencen pronto": "Expiring soon",
        "Actividad reciente": "Recent activity",
        "Esta semana": "This week",
        "Nuevo contrato firmado": "New lease signed",
        "Marta · Habitación 2 · Calle Mayor": "Marta · Room 2 · Calle Mayor",
        "Renta de mayo cobrada": "May rent collected",
        "Carlos · Habitación 1": "Carlos · Room 1",
        "Nuevo inquilino registrado": "New tenant added",
        "Laura entra el 1 de junio": "Laura moves in June 1",
        "Mantenimiento programado": "Maintenance scheduled",
        "Calefactor · Calle del Sol": "Heater · Calle del Sol",
        "Inquilinos": "Tenants",
        "Finanzas": "Finances",
        "Documentos": "Documents",
        "Habitación 1": "Room 1",
        "Habitación 2": "Room 2",
        "Habitación 3": "Room 3",
        "Habitación 4": "Room 4",
        "Habitación 1 · Calle Mayor": "Room 1 · Calle Mayor",
        "Habitación 2 · Calle Mayor": "Room 2 · Calle Mayor",
        "Habitación 3 · Calle Mayor": "Room 3 · Calle Mayor",
        "Habitación 1 · Calle del Sol": "Room 1 · Calle del Sol",
        "Habitación 2 · Calle del Sol": "Room 2 · Calle del Sol",
        "Renueva 14 ago": "Renews Aug 14",
        "Renueva 30 sep": "Renews Sep 30",
        "Entra 1 jun": "Moves in Jun 1",
        "Vence en 18 días": "Expires in 18 days",
        "Renueva 12 nov": "Renews Nov 12",
        "Renueva 5 mar": "Renews Mar 5",
        "Avisos": "Alerts",
        "Siempre un paso por delante": "Always one step ahead",
        "Nunca pierdas un contrato ni una fecha clave": "Never miss a lease or a key date",
        "Contrato vence en 18 días": "Lease expires in 18 days",
        "Renovar": "Renew",
        "Renovación en 30 días": "Renewal in 30 days",
        "Preparar": "Prepare",
        "Nuevo inquilino entra el 1 de junio": "New tenant moves in June 1",
        "Laura Ruiz · Habitación 3": "Laura Ruiz · Room 3",
        "Ver detalles": "View details",
        "Invitación pendiente": "Pending invitation",
        "María quiere compartir 'Calle del Sol'": "María wants to share 'Calle del Sol'",
        "Aceptar": "Accept",
        "Resumen semanal listo": "Weekly summary ready",
        "5 movimientos · 2 renovaciones esta semana": "5 entries · 2 renewals this week",
        "Ver": "View",
        "Ocupada": "Occupied",
        "Disponible": "Available",
        "Entra pronto": "Moving in",
        "Activo": "Active",
        "Vence pronto": "Expiring",
    ]

    /// Spanish literal in, localized literal out.
    static func t(_ spanish: String) -> String {
        isEnglish ? (english[spanish] ?? spanish) : spanish
    }
}
