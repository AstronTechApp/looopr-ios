import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var isExporting = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

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

                    Text(L10n.PrivacySettings.title)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.top, LoooprTheme.Spacing.sm)
                .padding(.bottom, LoooprTheme.Spacing.md)

                ScrollView {
                    VStack(spacing: LoooprTheme.Spacing.lg) {
                        // Data Export Section
                        dataExportSection

                        // Account Deletion Section
                        accountDeletionSection

                        // Info
                        Text(L10n.PrivacySettings.descriptionMessage)
                            .font(LoooprTheme.Typography.caption)
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            .padding(.horizontal, LoooprTheme.Spacing.sm)
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    .padding(.bottom, LoooprTheme.Spacing.xxl)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.PrivacySettings.exportComplete, isPresented: $showingExportSuccess) {
            Button(L10n.HealthSettings.ok) {}
        } message: {
            Text(L10n.PrivacySettings.dataSaved)
        }
        .alert(L10n.PrivacySettings.deleteAccount, isPresented: $showingDeleteConfirmation) {
            Button(L10n.PrivacySettings.deleteAccount, role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(L10n.Settings.cancel, role: .cancel) {}
        } message: {
            Text(L10n.PrivacySettings.deleteWarning)
        }
    }

    // MARK: - Data Export

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
            Text(L10n.PrivacySettings.yourData)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            VStack(spacing: 0) {
                Button {
                    Task { await exportData() }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: LoooprTheme.Typography.md))
                            .foregroundStyle(LoooprTheme.Colors.primary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.PrivacySettings.exportMyData)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            Text(L10n.PrivacySettings.downloadData)
                                .font(LoooprTheme.Typography.caption)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if isExporting {
                            ProgressView()
                                .tint(LoooprTheme.Colors.primary)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.vertical, LoooprTheme.Spacing.sm)
                }
                .buttonStyle(.plain)
                .disabled(isExporting)
            }
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .loooprShadow(LoooprTheme.Shadows.sm)
        }
    }

    // MARK: - Account Deletion

    private var accountDeletionSection: some View {
        VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xs) {
            Text(L10n.PrivacySettings.dangerZone)
                .font(LoooprTheme.Typography.label)
                .foregroundStyle(LoooprTheme.Colors.error)

            VStack(spacing: 0) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: LoooprTheme.Typography.md))
                            .foregroundStyle(LoooprTheme.Colors.error)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.PrivacySettings.deleteMyAccount)
                                .font(LoooprTheme.Typography.body)
                                .foregroundStyle(LoooprTheme.Colors.error)
                            Text(L10n.PrivacySettings.permanentlyRemoveData)
                                .font(LoooprTheme.Typography.caption)
                                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if isDeleting {
                            ProgressView()
                                .tint(LoooprTheme.Colors.error)
                        }
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.md)
                    .padding(.vertical, LoooprTheme.Spacing.sm)
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .loooprShadow(LoooprTheme.Shadows.sm)

            if let errorMessage {
                Text(errorMessage)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.error)
            }
        }
    }

    // MARK: - Actions

    private func exportData() async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let data = try await authService.exportUserData()

            // Save to Documents directory
            let fileName = "looopr-data-export-\(formattedDate()).json"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            try data.write(to: url)
            showingExportSuccess = true
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await authService.deleteAccount()

            // Clear local data
            let store: PersistenceStoring = ServiceContainer.shared.resolve(PersistenceStoring.self)
            try? store.delete(forKey: "looopr.recentRoutes")
            try? store.delete(forKey: "looopr.savedRoutes")
            try? store.delete(forKey: "looopr.completedRoutes")
            try? store.delete(forKey: "looopr.walkHistory")
        } catch {
            errorMessage = "Deletion failed: \(error.localizedDescription)"
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
