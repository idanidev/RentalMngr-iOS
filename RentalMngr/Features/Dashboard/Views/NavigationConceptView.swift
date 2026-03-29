/// NavigationConceptView.swift
/// Fichero de concepto — SOLO PREVIEW, no afecta a la app.
/// Abre en Xcode y activa el Canvas para ver el diseño propuesto.

import SwiftUI

// MARK: - Mock data

private struct MockProperty: Identifiable {
    let id = UUID()
    let name: String
    let city: String
    let occupiedRooms: Int
    let totalRooms: Int
    let monthlyIncome: Double
    var occupancyPct: Double { Double(occupiedRooms) / Double(totalRooms) }
}

private struct MockContract: Identifiable {
    let id = UUID()
    let tenantName: String
    let propertyName: String
    let daysLeft: Int
}

private let mockProperties: [MockProperty] = [
    MockProperty(name: "Calle Mayor 12", city: "Madrid", occupiedRooms: 4, totalRooms: 5, monthlyIncome: 2_400),
    MockProperty(name: "Av. Diagonal 80", city: "Barcelona", occupiedRooms: 2, totalRooms: 3, monthlyIncome: 1_800),
    MockProperty(name: "Gran Vía 55", city: "Madrid", occupiedRooms: 3, totalRooms: 3, monthlyIncome: 2_100),
]

private let mockContracts: [MockContract] = [
    MockContract(tenantName: "Carlos Ruiz", propertyName: "Calle Mayor 12", daysLeft: 8),
    MockContract(tenantName: "Ana Martín", propertyName: "Av. Diagonal 80", daysLeft: 22),
]

// MARK: - Root concept

struct NavigationConceptView: View {
    @State private var selectedTab: ConceptTab = .home
    @State private var showSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ConceptHomeTab(showSettings: $showSettings)
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(ConceptTab.home)

            ConceptPropertiesTab()
                .tabItem { Label("Propiedades", systemImage: "building.2.fill") }
                .tag(ConceptTab.properties)

            ConceptFinancesTab()
                .tabItem { Label("Finanzas", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(ConceptTab.finances)
        }
        .sheet(isPresented: $showSettings) {
            ConceptSettingsSheet()
        }
    }
}

private enum ConceptTab { case home, properties, finances }

// MARK: - Home tab

private struct ConceptHomeTab: View {
    @Binding var showSettings: Bool
    @State private var homeTab: HomeSection = .resumen

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Metric banner
                    metricBanner

                    // Quick actions
                    quickActions
                        .padding(.top, 16)

                    // Internal tabs
                    internalTabBar
                        .padding(.top, 20)

                    // Content
                    Group {
                        switch homeTab {
                        case .resumen:   resumenContent
                        case .contratos: contratosContent
                        case .actividad: actividadContent
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Text("D")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("RentalMngr")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16))
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
    }

    // Monthly income + occupancy row
    private var metricBanner: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ingresos este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("6.300 €")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("+4,2%")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Ocupación")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("81,8%")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // Quick action icons
    private var quickActions: some View {
        let actions: [(String, String, Color)] = [
            ("Propiedad", "plus.circle.fill", .blue),
            ("Inquilino", "person.badge.plus", .purple),
            ("Gasto", "minus.circle.fill", .red),
            ("Cobrar", "eurosign.circle.fill", .green),
            ("Más", "ellipsis.circle.fill", .gray),
        ]
        return HStack(spacing: 0) {
            ForEach(actions, id: \.0) { label, icon, color in
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(color.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(color)
                    }
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // Horizontal tab bar inside the scroll
    private var internalTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(HomeSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) { homeTab = section }
                    } label: {
                        VStack(spacing: 6) {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(homeTab == section ? .semibold : .regular)
                                .foregroundStyle(homeTab == section ? .primary : .secondary)
                            Rectangle()
                                .fill(homeTab == section ? Color.accentColor : .clear)
                                .frame(height: 2)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
    }

    // --- Resumen content ---
    private var resumenContent: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 12) {
                statCard(value: "3", label: "Propiedades", icon: "building.2.fill", color: .blue)
                statCard(value: "9/11", label: "Habitaciones", icon: "bed.double.fill", color: .purple)
                statCard(value: "2", label: "Vencimientos", icon: "clock.badge.exclamationmark", color: .orange)
            }
            .padding(.horizontal, 16)

            // Property cards
            VStack(alignment: .leading, spacing: 8) {
                Text("Mis propiedades")
                    .font(.headline)
                    .padding(.horizontal, 16)

                ForEach(mockProperties) { property in
                    ConceptPropertyCard(property: property)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // --- Contratos content ---
    private var contratosContent: some View {
        VStack(spacing: 8) {
            ForEach(mockContracts) { contract in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(contract.tenantName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(contract.propertyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Vence en \(contract.daysLeft)d")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(contract.daysLeft < 15 ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundStyle(contract.daysLeft < 15 ? .red : .orange)
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    // --- Actividad content ---
    private var actividadContent: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(i % 2 == 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: i % 2 == 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(i % 2 == 0 ? .green : .red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i % 2 == 0 ? "Alquiler cobrado" : "Gasto registrado")
                            .font(.subheadline)
                        Text("Calle Mayor 12 · hace \(i + 1)h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(i % 2 == 0 ? "+480 €" : "-120 €")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(i % 2 == 0 ? .green : .red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

                if i < 4 { Divider().padding(.leading, 64) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private enum HomeSection: CaseIterable {
    case resumen, contratos, actividad
    var title: String {
        switch self {
        case .resumen:   return "Resumen"
        case .contratos: return "Contratos"
        case .actividad: return "Actividad"
        }
    }
}

// MARK: - Property card

private struct ConceptPropertyCard: View {
    let property: MockProperty

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(property.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(property.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Mini occupancy bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemFill)).frame(height: 4)
                        Capsule()
                            .fill(property.occupancyPct > 0.8 ? Color.green : Color.orange)
                            .frame(width: geo.size.width * property.occupancyPct, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(property.monthlyIncome)) €")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("\(property.occupiedRooms)/\(property.totalRooms) hab.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Properties tab (simplified)

private struct ConceptPropertiesTab: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(mockProperties) { property in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(property.name).font(.headline)
                            Text(property.city).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(property.occupiedRooms)/\(property.totalRooms)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Propiedades")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { } label: { Image(systemName: "magnifyingglass") }
                }
            }
        }
    }
}

// MARK: - Finances tab (placeholder con espacio para gráficos)

private struct ConceptFinancesTab: View {
    @State private var financeTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Chart placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingresos vs Gastos")
                            .font(.headline)
                            .padding(.horizontal)

                        // Simulated bar chart
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(["E","F","M","A","M","J"], id: \.self) { month in
                                let incomeH = Double.random(in: 60...120)
                                let expenseH = Double.random(in: 20...60)
                                VStack(spacing: 3) {
                                    HStack(alignment: .bottom, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green.opacity(0.7))
                                            .frame(width: 14, height: incomeH)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.red.opacity(0.7))
                                            .frame(width: 14, height: expenseH)
                                    }
                                    Text(month)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        .frame(height: 140)

                        HStack(spacing: 16) {
                            Label("Ingresos", systemImage: "circle.fill")
                                .foregroundStyle(.green)
                            Label("Gastos", systemImage: "circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Summary cards
                    HStack(spacing: 12) {
                        financeCard(title: "Cobrado", value: "4.200 €", color: .green)
                        financeCard(title: "Pendiente", value: "2.100 €", color: .orange)
                        financeCard(title: "Gastos", value: "980 €", color: .red)
                    }
                    .padding(.horizontal)

                    // Month picker
                    HStack {
                        Button { } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text("Marzo 2026")
                            .font(.headline)
                        Spacer()
                        Button { } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Finanzas")
        }
    }

    private func financeCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Settings sheet (sale desde el avatar)

private struct ConceptSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Perfil") {
                    Label("dani@example.com", systemImage: "person.circle")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                Section("Apariencia") {
                    Label("Tema", systemImage: "moon.circle")
                    Label("Idioma", systemImage: "globe")
                }
                Section("Herramientas") {
                    Label("Buscar", systemImage: "magnifyingglass")
                    Label("Mis invitaciones", systemImage: "envelope.badge")
                    Label("Notificaciones", systemImage: "bell.badge")
                }
                Section("App") {
                    LabeledContent("Versión", value: "1.0")
                }
                Section {
                    Button(role: .destructive) { } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Concepto navegación — Light") {
    NavigationConceptView()
        .preferredColorScheme(.light)
}

#Preview("Concepto navegación — Dark") {
    NavigationConceptView()
        .preferredColorScheme(.dark)
}
