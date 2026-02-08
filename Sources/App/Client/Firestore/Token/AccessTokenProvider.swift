/// Errors that can occur when providing or fetching access tokens.
enum AccessTokenProviderError: Error, Sendable {
    /// Indicates a configuration error related to the access token provider.
    /// - Parameter message: A descriptive message about the configuration issue.
    case configurationError(message: String)

    /// Indicates that a new access token could not be fetched due to an underlying error.
    /// - Parameter underlying: The underlying error that caused the failure.
    case unableToFetchNewToken(underlying: Error)
}

/// A type that provides access tokens asynchronously, potentially handling refresh and error cases.
protocol AccessTokenProvider: Sendable {
    /// Retrieves the current access token asynchronously, refreshing it if needed.
    /// - Returns: The access token string if available, or nil if not present.
    /// - Throws: `AccessTokenProviderError` if an error occurs while fetching the token.
    func getToken() async throws(AccessTokenProviderError) -> String?
}
