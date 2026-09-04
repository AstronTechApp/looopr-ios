import SwiftUI
import RevenueCat
import RevenueCatUI

/// The Looopr Premium paywall. Reachable from Settings while the paywall is
/// dark (for sandbox testing), and from freemium gates once
/// `AppConfiguration.freemium.paywallEnabled` is flipped on at launch.
///
/// Renders RevenueCat's remotely-configurable paywall template (build/edit
/// it in the RevenueCat dashboard under Paywalls, no app update required)
/// rather than a hand-built package picker, so pricing/copy/layout changes
/// don't need a release.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PaywallViewModel()

    var body: some View {
        Group {
            if viewModel.isConfigured {
                RevenueCatUI.PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        viewModel.handlePurchaseCompleted(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        viewModel.handleRestoreCompleted(customerInfo)
                    }
                    .onRequestedDismissal {
                        dismiss()
                    }
            } else {
                unavailableView
            }
        }
        .onAppear {
            viewModel.trackShown()
            viewModel.observeEntitlement()
        }
        .onDisappear { viewModel.stopObservingEntitlement() }
        .onChange(of: viewModel.didUnlock) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // MARK: - Fallback (RevenueCat not configured — no API key in Secrets)

    private var unavailableView: some View {
        VStack(spacing: LoooprTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(LoooprTheme.Colors.primary)
            Text(L10n.Paywall.title)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)
            Text(L10n.Paywall.unavailable)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LoooprTheme.Colors.background)
        .navigationTitle(L10n.Paywall.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
