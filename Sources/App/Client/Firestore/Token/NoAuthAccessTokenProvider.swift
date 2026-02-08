/// An access token provider that always returns `nil`, indicating no authentication token.
///
/// Use `NoAuthAccessTokenProvider` when connecting to the Firestore emulator, which does not require authentication.
/// Returning `nil` from `getToken()` signals the HTTP client to omit the `Authorization` header in requests.
///
/// ## Usage
///
/// Configure the Firestore client for the emulator as follows:
///
/// ```swift
/// let config = FirestoreConfig(
///     projectId: "test-project",
///     apiRoot: URL(string: "http://localhost:8080/v1")!
/// )
/// let tokenProvider = NoAuthAccessTokenProvider()
/// let httpClient = FirestoreHTTPClient(config: config, tokenProvider: tokenProvider)
/// ```
///
/// - SeeAlso: ``EnvironmentAccessTokenProvider``, ``FirestoreHTTPClient``
struct NoAuthAccessTokenProvider: AccessTokenProvider {
    /// Returns `nil` indicating no authentication token is provided.
    ///
    /// The Firestore emulator does not require authentication, so this method always returns `nil`.
    /// The HTTP client interprets `nil` as an instruction to omit the `Authorization` header.
    ///
    /// - Returns: Always `nil`.
    ///
    /// - Throws: Never throws.
    func getToken() async throws(AccessTokenProviderError) -> String? {
        return nil
    }
}
