import Foundation

protocol AuthProviding: Sendable {
    var currentUserID: UUID? { get async }
    var isAuthenticated: Bool { get async }

    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle() async throws
    func signOut() async throws
    func deleteAccount() async throws
}
