import Foundation
import AuthenticationServices
import Supabase

@Observable
final class AuthService: @unchecked Sendable {
    private let supabase: SupabaseClientProvider

    @MainActor private(set) var userID: UUID?
    @MainActor private(set) var isSignedIn = false
    @MainActor private(set) var userEmail: String?
    @MainActor private(set) var userDisplayName: String?

    init(supabase: SupabaseClientProvider) {
        self.supabase = supabase
    }

    // MARK: - Session Management

    @MainActor
    func restoreSession() async {
        do {
            let session = try await supabase.client.auth.session
            applySession(session)
        } catch {
            // No valid session — user needs to sign in
            clearSession()
        }
    }

    @MainActor
    func observeAuthChanges() {
        Task { [weak self] in
            guard let self else { return }
            for await (event, session) in self.supabase.client.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedIn, .tokenRefreshed, .userUpdated:
                        if let session {
                            self.applySession(session)
                        }
                    case .signedOut:
                        self.clearSession()
                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Apple Sign In

    @MainActor
    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await supabase.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        applySession(session)
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        try await supabase.client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "looopr://auth-callback")
        )
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async throws {
        try await supabase.client.auth.signOut()
        clearSession()
    }

    // MARK: - Delete Account (GDPR Art. 17)

    @MainActor
    func deleteAccount() async throws {
        guard let userID else { return }
        // Call the delete-account Edge Function
        try await supabase.client.functions.invoke(
            "hyper-endpoint",
            options: .init(body: ["user_id": userID.uuidString])
        )
        clearSession()
    }

    // MARK: - Data Export (GDPR Art. 20)

    func exportUserData() async throws -> Data {
        try await supabase.client.functions.invoke(
            "hyper-task"
        ) { data, _ in
            data
        }
    }

    // MARK: - Private

    @MainActor
    private func applySession(_ session: Session) {
        userID = session.user.id
        isSignedIn = true
        userEmail = session.user.email
        userDisplayName = session.user.userMetadata["full_name"]?.stringValue
            ?? session.user.userMetadata["name"]?.stringValue
    }

    @MainActor
    private func clearSession() {
        userID = nil
        isSignedIn = false
        userEmail = nil
        userDisplayName = nil
    }
}

// MARK: - AuthProviding Conformance

extension AuthService: AuthProviding {
    var currentUserID: UUID? {
        get async { await MainActor.run { userID } }
    }

    var isAuthenticated: Bool {
        get async { await MainActor.run { isSignedIn } }
    }
}

// MARK: - Apple Sign In Helper

final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<(idToken: String, nonce: String), Error>?
    let nonce: String

    init(nonce: String) {
        self.nonce = nonce
    }

    func signIn() async throws -> (idToken: String, nonce: String) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce.sha256

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.missingIDToken)
            return
        }
        continuation?.resume(returning: (idToken: idToken, nonce: nonce))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum AuthError: LocalizedError {
    case missingIDToken
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingIDToken: return "Failed to retrieve Apple ID token."
        case .notAuthenticated: return "You must be signed in to perform this action."
        }
    }
}

// MARK: - String SHA256

import CryptoKit

extension String {
    var sha256: String {
        let data = Data(utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Generate a random nonce for Apple Sign In
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                precondition(status == errSecSuccess)
                return random
            }
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}
