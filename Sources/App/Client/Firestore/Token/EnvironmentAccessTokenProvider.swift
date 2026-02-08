import Foundation

/// An access token provider that reads tokens from environment variables.
///
/// `EnvironmentAccessTokenProvider` is useful for scenarios where you want to
/// provide OAuth2 tokens via environment variables rather than relying on
/// automatic discovery via the GCP Metadata Service.
///
/// ## Use Cases
///
/// - Running on non-GCP infrastructure but still needing Firestore access
/// - Testing with pre-generated tokens
/// - CI/CD environments with service account tokens
/// - Development with explicit token management
///
/// ## Configuration
///
/// Set the `FIRESTORE_ACCESS_TOKEN` environment variable with a valid OAuth2 bearer token:
///
/// ```bash
/// export FIRESTORE_ACCESS_TOKEN="ya29.a0AfH6SMBx..."
/// ```
///
/// The token must be:
/// - A valid OAuth2 bearer token
/// - Non-empty string
/// - Have Firestore API permissions
///
/// ## Token Lifetime
///
/// This provider returns the token on every call without caching or refresh.
/// For long-running applications, consider implementing token refresh logic
/// or using ``MetadataServerTokenRetriever`` with ``CachedAccessTokenProvider`` instead.
///
/// - SeeAlso: ``MetadataServerTokenRetriever``, ``CachedAccessTokenProvider``, ``NoAuthAccessTokenProvider``
struct EnvironmentAccessTokenProvider: AccessTokenProvider {
    /// Returns the Firestore access token from the environment variable.
    ///
    /// Reads the `FIRESTORE_ACCESS_TOKEN` environment variable and returns it.
    /// The variable must be present and non-empty.
    ///
    /// - Returns: The OAuth2 bearer token from the environment variable
    ///
    /// - Throws: ``AccessTokenProviderError.configurationError`` if the environment variable
    ///   is not set or is empty
    func getToken() async throws(AccessTokenProviderError) -> String? {
        guard let token = ProcessInfo.processInfo.environment["FIRESTORE_ACCESS_TOKEN"],
              !token.isEmpty
        else {
            throw AccessTokenProviderError.configurationError(
                message: "Environment variable 'FIRESTORE_ACCESS_TOKEN' is not set or is empty."
            )
        }
        return token
    }
}
