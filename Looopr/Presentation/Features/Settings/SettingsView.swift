import SwiftUI
import SafariServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsManager.shared
    @State private var localization = LocalizationManager.shared
    @State private var showingNotificationDenied = false
    @State private var showingShareSheet = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: LoooprTheme.Typography.lg, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    }

                    Spacer()

                    Text(L10n.Settings.title)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.top, LoooprTheme.Spacing.sm)
                .padding(.bottom, LoooprTheme.Spacing.md)

                ScrollView {
                    VStack(spacing: LoooprTheme.Spacing.lg) {
                        accountSection
                        walkPreferencesSection
                        healthSection
                        notificationsSection
                        privacySection
                        aboutSection
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    .padding(.bottom, LoooprTheme.Spacing.huge + LoooprTheme.Spacing.xxl)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.Settings.notificationsDisabled, isPresented: $showingNotificationDenied) {
            Button(L10n.Settings.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.Settings.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.enableNotificationsMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            let message = L10n.Share.discoveringRoutes
            // Replace APP_STORE_ID with actual ID when available
            let appURL = URL(string: "https://apps.apple.com/app/idAPP_STORE_ID")!
            ShareSheet(items: [message, appURL])
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            // Replace with actual URL when available
            SafariView(url: URL(string: "https://looopr.app/privacy")!)
        }
        .alert(L10n.LanguageRestart.title, isPresented: $localization.showRestartAlert) {
            Button(L10n.LanguageRestart.restart) { }
        } message: {
            Text(L10n.LanguageRestart.message)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        SettingsSectionCard(title: L10n.Settings.account) {
            SettingsTextField(
                icon: "person.fill",
                title: L10n.Settings.displayName,
                text: $settings.displayName
            )
        }
    }

    // MARK: - Walk Preferences Section

    private var walkPreferencesSection: some View {
        SettingsSectionCard(title: L10n.Settings.walkPreferences) {
            VStack(spacing: 0) {
                // Distance Units picker (System Default / Metric / Imperial)
                SettingsRow(icon: "ruler", title: L10n.Settings.distanceUnits) {
                    Menu {
                        ForEach(UnitPreference.allCases, id: \.self) { pref in
                            Button {
                                settings.unitPreference = pref
                            } label: {
                                HStack {
                                    Text(pref.label)
                                    if settings.unitPreference == pref {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: LoooprTheme.Spacing.xxs) {
                            Text(settings.unitPreference.label)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }
                }

                Divider()
                    .padding(.leading, 44)

                // Walking pace
                NavigationLink {
                    WalkingPaceSelectionView()
                } label: {
                    SettingsRow(icon: "figure.walk", title: L10n.Settings.walkingPace) {
                        HStack(spacing: LoooprTheme.Spacing.xxs) {
                            Text(settings.walkingPace.label)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 44)

                // Language
                SettingsRow(icon: "globe", title: L10n.Settings.language) {
                    Menu {
                        ForEach(LocalizationManager.SupportedLanguage.allCases, id: \.self) { lang in
                            Button {
                                localization.setLanguage(lang)
                            } label: {
                                HStack {
                                    Text(lang.displayName)
                                    if localization.currentLanguage == lang {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: LoooprTheme.Spacing.xxs) {
                            Text(localization.currentLanguage.displayName)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Health Section

    private var healthSection: some View {
        SettingsSectionCard(title: L10n.Settings.health) {
            NavigationLink {
                HealthSettingsView()
            } label: {
                SettingsRow(icon: "heart.fill", title: L10n.Settings.appleHealth) {
                    HStack(spacing: LoooprTheme.Spacing.xxs) {
                        Text(L10n.Settings.notConnected)
                            .font(LoooprTheme.Typography.body)
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SettingsSectionCard(title: L10n.Settings.notifications) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.fill",
                    title: L10n.Settings.walkReminder,
                    subtitle: L10n.Settings.walkReminderDescription,
                    isOn: Binding(
                        get: { settings.walkReminderEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let granted = await settings.requestNotificationAuthorisation()
                                    if granted {
                                        settings.walkReminderEnabled = true
                                    } else {
                                        showingNotificationDenied = true
                                    }
                                }
                            } else {
                                settings.walkReminderEnabled = false
                            }
                        }
                    )
                )

                if settings.walkReminderEnabled {
                    Divider()
                        .padding(.leading, 44)

                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: LoooprTheme.Typography.md))
                            .foregroundStyle(LoooprTheme.Colors.primary)
                            .frame(width: 28)

                        Text(L10n.Settings.reminderTime)
                            .font(LoooprTheme.Typography.body)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)

                        Spacer()

                        DatePicker(
                            "",
                            selection: $settings.walkReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .tint(LoooprTheme.Colors.primary)
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.vertical, LoooprTheme.Spacing.sm)
                }

                Divider()
                    .padding(.leading, 44)

                SettingsToggleRow(
                    icon: "chart.bar.fill",
                    title: L10n.Settings.weeklySummary,
                    subtitle: L10n.Settings.weeklySummaryDescription,
                    isOn: Binding(
                        get: { settings.weeklyProgressEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let granted = await settings.requestNotificationAuthorisation()
                                    if granted {
                                        settings.weeklyProgressEnabled = true
                                    } else {
                                        showingNotificationDenied = true
                                    }
                                }
                            } else {
                                settings.weeklyProgressEnabled = false
                            }
                        }
                    )
                )
            }
        }
    }

    // MARK: - Privacy & Data Section

    private var privacySection: some View {
        SettingsSectionCard(title: L10n.Settings.privacyAndData) {
            VStack(spacing: 0) {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    SettingsRow(icon: "hand.raised.fill", title: L10n.Settings.privacyAndDataLink) {
                        HStack(spacing: LoooprTheme.Spacing.xxs) {
                            Text(L10n.Settings.manage)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 44)

                // Sign out
                Button {
                    Task {
                        let authService: AuthService? = ServiceContainer.shared.resolveOptional(AuthService.self)
                        try? await authService?.signOut()
                    }
                } label: {
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: L10n.Settings.signOut) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSectionCard(title: L10n.Settings.about) {
            VStack(spacing: 0) {
                // Brand logo
                VStack(spacing: LoooprTheme.Spacing.xs) {
                    Image("LoooprLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)

                    Text("Looopr")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LoooprTheme.Spacing.md)

                Divider()

                // App version
                SettingsRow(icon: "info.circle", title: L10n.Settings.appVersion) {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                    Text("\(version) (\(build))")
                        .font(LoooprTheme.Typography.body)
                        .foregroundStyle(LoooprTheme.Colors.textSecondary)
                }

                Divider()
                    .padding(.leading, 44)

                // Rate Looopr
                Button {
                    // Replace APP_STORE_ID with actual ID when available
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/idAPP_STORE_ID?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SettingsRow(icon: "star.fill", title: L10n.Settings.rateLooopr) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 44)

                // Share Looopr
                Button {
                    showingShareSheet = true
                } label: {
                    SettingsRow(icon: "square.and.arrow.up", title: L10n.Settings.shareLooopr) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 44)

                // Privacy Policy
                Button {
                    showingPrivacyPolicy = true
                } label: {
                    SettingsRow(icon: "lock.shield", title: L10n.Settings.privacyPolicy) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Settings Section Card

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
            Text(title)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            VStack(spacing: 0) {
                content()
            }
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .loooprShadow(LoooprTheme.Shadows.sm)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.md))
                .foregroundStyle(LoooprTheme.Colors.primary)
                .frame(width: 28)

            Text(title)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.vertical, LoooprTheme.Spacing.sm)
    }
}

// MARK: - Settings Toggle Row

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.md))
                .foregroundStyle(LoooprTheme.Colors.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LoooprTheme.Typography.body)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(LoooprTheme.Colors.primary)
        }
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.vertical, LoooprTheme.Spacing.sm)
    }
}

// MARK: - Settings Text Field

private struct SettingsTextField: View {
    let icon: String
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.md))
                .foregroundStyle(LoooprTheme.Colors.primary)
                .frame(width: 28)

            Text(title)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Spacer()

            TextField("Name", text: $text)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.vertical, LoooprTheme.Spacing.sm)
    }
}

// MARK: - Unit Toggle Pill

/// Custom two-option pill toggle for km/mi with high-contrast selected state.
/// Teal filled pill slides behind the selected option with white bold text;
/// unselected option shows secondary grey text.
private struct UnitTogglePill: View {
    @Binding var selectedUnits: SettingsManager.Units

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: geo.size.height / 2)
                    .fill(LoooprTheme.Colors.surfaceSecondary)

                // Sliding teal pill
                RoundedRectangle(cornerRadius: (geo.size.height - 6) / 2)
                    .fill(LoooprTheme.Colors.primary)
                    .frame(width: halfWidth - 4, height: geo.size.height - 6)
                    .offset(x: selectedUnits == .kilometres
                            ? -(halfWidth / 2 - 2)
                            : (halfWidth / 2 - 2))
                    .animation(.easeInOut(duration: 0.2), value: selectedUnits)

                // Labels
                HStack(spacing: 0) {
                    Button {
                        guard selectedUnits != .kilometres else { return }
                        selectedUnits = .kilometres
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("km")
                            .font(.system(size: 15, weight: selectedUnits == .kilometres ? .bold : .regular))
                            .foregroundStyle(selectedUnits == .kilometres ? .white : LoooprTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard selectedUnits != .miles else { return }
                        selectedUnits = .miles
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("mi")
                            .font(.system(size: 15, weight: selectedUnits == .miles ? .bold : .regular))
                            .foregroundStyle(selectedUnits == .miles ? .white : LoooprTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 120, height: 36)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
