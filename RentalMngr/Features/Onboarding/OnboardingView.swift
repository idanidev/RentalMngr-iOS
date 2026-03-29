import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let accentColor: Color
    let title: String
    let description: String
    let bullets: [(icon: String, text: String)]
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "house.fill",
            accentColor: Color(red: 1.0, green: 0.45, blue: 0.1),
            title: String(localized: "Everything Under Control", locale: LanguageService.currentLocale, comment: "Onboarding page 1 title"),
            description: String(localized: "Manage all your rental properties in one place", locale: LanguageService.currentLocale, comment: "Onboarding page 1 desc"),
            bullets: [
                ("building.2", String(localized: "Properties with rooms, photos and occupancy", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("person.2.fill", String(localized: "Tenants, contracts and deposits tracked", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("arrow.trianglehead.2.clockwise.rotate.90", String(localized: "Real-time sync across all your devices", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
            ]
        ),
        OnboardingPage(
            icon: "building.2.fill",
            accentColor: Color(red: 0.2, green: 0.5, blue: 1.0),
            title: String(localized: "Properties & Rooms", locale: LanguageService.currentLocale, comment: "Onboarding page 2 title"),
            description: String(localized: "Every detail of every property at your fingertips", locale: LanguageService.currentLocale, comment: "Onboarding page 2 desc"),
            bullets: [
                ("bed.double.fill", String(localized: "Private rooms and common areas", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("chart.pie.fill", String(localized: "Occupancy rate always visible", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("photo.on.rectangle.angled", String(localized: "Photos and inventory per room", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
            ]
        ),
        OnboardingPage(
            icon: "person.2.fill",
            accentColor: Color(red: 0.55, green: 0.25, blue: 0.95),
            title: String(localized: "Tenants & Contracts", locale: LanguageService.currentLocale, comment: "Onboarding page 3 title"),
            description: String(localized: "Never lose track of a contract or payment again", locale: LanguageService.currentLocale, comment: "Onboarding page 3 desc"),
            bullets: [
                ("doc.text.fill", String(localized: "Contracts with expiry and renewal dates", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("eurosign.circle.fill", String(localized: "Deposits and monthly payments tracked", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("folder.fill", String(localized: "All tenant documents in one place", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
            ]
        ),
        OnboardingPage(
            icon: "eurosign.circle.fill",
            accentColor: Color(red: 0.1, green: 0.75, blue: 0.45),
            title: String(localized: "Crystal Clear Finances", locale: LanguageService.currentLocale, comment: "Onboarding page 4 title"),
            description: String(localized: "Know exactly how much your properties earn", locale: LanguageService.currentLocale, comment: "Onboarding page 4 desc"),
            bullets: [
                ("arrow.up.arrow.down.circle.fill", String(localized: "Income and expenses per property", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("bolt.fill", String(localized: "Utility bills broken down by room", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("calendar", String(localized: "Full financial history with filters", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
            ]
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            accentColor: Color(red: 0.95, green: 0.25, blue: 0.3),
            title: String(localized: "Always One Step Ahead", locale: LanguageService.currentLocale, comment: "Onboarding page 5 title"),
            description: String(localized: "Smart alerts so nothing ever slips through the cracks", locale: LanguageService.currentLocale, comment: "Onboarding page 5 desc"),
            bullets: [
                ("clock.badge.exclamationmark.fill", String(localized: "Alerts before contracts expire", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("slider.horizontal.3", String(localized: "Fully customisable reminders", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
                ("person.2.badge.key.fill", String(localized: "Share access with your team", locale: LanguageService.currentLocale, comment: "Onboarding bullet")),
            ]
        ),
    ]

    var body: some View {
        ZStack {
            // Animated background — smoothly transitions between page colors
            pages[currentPage].accentColor
                .opacity(0.08)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button top-right
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage = pages.count - 1
                            }
                        } label: {
                            Text(String(localized: "Skip", locale: LanguageService.currentLocale, comment: "Onboarding skip button"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.easeInOut, value: currentPage)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page, isActive: currentPage == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom area
                VStack(spacing: 28) {
                    // Dot indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                    ? pages[currentPage].accentColor
                                    : Color.primary.opacity(0.2))
                                .frame(width: i == currentPage ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Primary CTA
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            withAnimation(.smooth) {
                                hasSeenOnboarding = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(
                                currentPage < pages.count - 1
                                    ? String(localized: "Continue", locale: LanguageService.currentLocale, comment: "Onboarding continue button")
                                    : String(localized: "Get Started", locale: LanguageService.currentLocale, comment: "Onboarding final button")
                            )
                            .font(.headline)
                            if currentPage < pages.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(pages[currentPage].accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: pages[currentPage].accentColor.opacity(0.4),
                                radius: 12, y: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Single Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Icon hero card
            ZStack {
                // Glow effect behind icon
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.accentColor.opacity(0.25), page.accentColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.accentColor.opacity(0.5), page.accentColor.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.accentColor, page.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: page.accentColor.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6)
                        .delay(0.05), value: appeared)
            }
            .frame(height: 220)
            .padding(.top, 24)

            // Text content
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7)
                            .delay(0.1), value: appeared)

                    Text(page.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7)
                            .delay(0.15), value: appeared)
                }

                // Bullet points card
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(page.bullets.enumerated()), id: \.offset) { index, bullet in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(page.accentColor.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: bullet.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(page.accentColor)
                            }
                            Text(bullet.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.8))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .offset(x: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.75)
                                .delay(0.2 + Double(index) * 0.08),
                            value: appeared
                        )

                        if index < page.bullets.count - 1 {
                            Divider()
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75)
                    .delay(0.18), value: appeared)
            }
            .padding(.top, 24)

            Spacer()
        }
        .onAppear {
            guard isActive else { return }
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                appeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                }
            }
        }
    }
}
