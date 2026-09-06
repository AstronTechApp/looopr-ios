import SwiftUI

/// "Send feedback" sheet, opened from Settings → Support. One message box,
/// an optional reply address, and a send button. Version, OS, device and
/// language are attached by `LiveFeedbackService` without the user having
/// to type them.
struct FeedbackSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var replyEmail = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case message, email }

    private let service: FeedbackSending? = ServiceContainer.shared.resolveOptional(FeedbackSending.self)

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedMessage.isEmpty && !isSending && service != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LoooprTheme.Colors.background
                    .ignoresSafeArea()

                if didSend {
                    sentState
                } else {
                    form
                }
            }
            .navigationTitle(L10n.SendFeedback.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSend ? L10n.Misc.done : L10n.Misc.cancel) {
                        dismiss()
                    }
                    .foregroundStyle(LoooprTheme.Colors.primary)
                }
            }
        }
        .onAppear { focusedField = .message }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.lg) {
                Text(L10n.SendFeedback.prompt)
                    .font(LoooprTheme.Typography.body)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)

                // Message
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text(L10n.SendFeedback.messagePlaceholder)
                            .font(LoooprTheme.Typography.body)
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            .padding(.horizontal, LoooprTheme.Spacing.md + 4)
                            .padding(.vertical, LoooprTheme.Spacing.md + 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $message)
                        .font(LoooprTheme.Typography.body)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(LoooprTheme.Spacing.md)
                        .frame(minHeight: 160)
                        .focused($focusedField, equals: .message)
                }
                .background(LoooprTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: LoooprTheme.Radius.card)
                        .stroke(focusedField == .message ? LoooprTheme.Colors.primary : LoooprTheme.Colors.border, lineWidth: 1)
                )

                // Reply email
                VStack(alignment: .leading, spacing: LoooprTheme.Spacing.xxs) {
                    TextField(L10n.SendFeedback.emailLabel, text: $replyEmail)
                        .font(LoooprTheme.Typography.body)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        .textFieldStyle(.plain)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($focusedField, equals: .email)
                        .onSubmit { if canSend { Task { await send() } } }
                        .padding(LoooprTheme.Spacing.md)
                        .background(LoooprTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.input))
                        .overlay(
                            RoundedRectangle(cornerRadius: LoooprTheme.Radius.input)
                                .stroke(focusedField == .email ? LoooprTheme.Colors.primary : LoooprTheme.Colors.border, lineWidth: 1)
                        )

                    Text(L10n.SendFeedback.emailHint)
                        .font(LoooprTheme.Typography.caption)
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        .padding(.horizontal, LoooprTheme.Spacing.xxs)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(LoooprTheme.Typography.subheadline)
                        .foregroundStyle(LoooprTheme.Colors.error)
                }

                Button {
                    Task { await send() }
                } label: {
                    HStack(spacing: LoooprTheme.Spacing.xs) {
                        if isSending {
                            ProgressView().tint(.white)
                        }
                        Text(isSending ? L10n.SendFeedback.sending : L10n.SendFeedback.send)
                    }
                }
                .buttonStyle(.loooprPrimary)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.5)

                Text(L10n.SendFeedback.footer)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.top, LoooprTheme.Spacing.md)
            .padding(.bottom, LoooprTheme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sent

    private var sentState: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(LoooprTheme.Colors.primary)

            Text(L10n.SendFeedback.sentTitle)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Text(L10n.SendFeedback.sentBody)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button(L10n.Misc.done) { dismiss() }
                .buttonStyle(.loooprSecondary)
                .padding(.top, LoooprTheme.Spacing.md)
        }
        .padding(.horizontal, LoooprTheme.Spacing.xxl)
    }

    // MARK: - Actions

    private func send() async {
        guard canSend, let service else { return }

        let email = trimmedEmail
        if !email.isEmpty && !Self.looksLikeEmail(email) {
            errorMessage = L10n.SendFeedback.errorEmail
            focusedField = .email
            return
        }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            try await service.send(FeedbackSubmission(
                message: trimmedMessage,
                replyEmail: email.isEmpty ? nil : email
            ))
            focusedField = nil
            withAnimation(LoooprTheme.Animation.snappy) { didSend = true }
        } catch FeedbackError.notSignedIn {
            errorMessage = L10n.SendFeedback.errorSignIn
        } catch {
            errorMessage = L10n.SendFeedback.errorSend
        }
    }

    /// Deliberately loose: one "@" with something on both sides and a dot
    /// after it. Rejecting a valid-but-unusual address is worse than
    /// letting a typo through.
    private static func looksLikeEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}

#Preview {
    FeedbackSheetView()
}
