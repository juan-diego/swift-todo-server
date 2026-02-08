import Foundation

/// An access token provider that caches tokens to avoid unnecessary fetches.
///
/// `CachedAccessTokenProvider` wraps another token retriever and implements
/// caching logic to improve performance by reusing valid tokens until they expire.
///
/// The provider will:
/// - Return cached tokens when still valid (with leeway for expiration)
/// - Fetch new tokens only when needed or when expired
/// - Handle token refresh automatically
///
/// This is particularly useful for applications that make frequent Firestore calls,
/// as it avoids redundant token fetches and improves response times.
actor CachedAccessTokenProvider: AccessTokenProvider {
    
    /// Cached access token.
    private var cachedToken: String?
    /// Expiration time of the cached token.
    private var tokenExpiry: Date?
    /// Seconds before expiry to proactively refresh.
    private let expiryLeeway: TimeInterval = 60
    /// The token retriever used to fetch new tokens.
    private let tokenRetriever: TokenRetriever
    
    /// Creates a cached access token provider.
    ///
    /// - Parameters:
    ///   - tokenRetriever: The retriever to use for fetching fresh tokens when needed.
    init(tokenRetriever: TokenRetriever) {
        self.tokenRetriever = tokenRetriever
    }
    
    /// Returns a valid access token, using cache when possible.
    ///
    /// This method checks if a cached token is still valid (with expiry leeway).
    /// If the token is expired or not present, it fetches a new one from the supplier.
    ///
    /// - Returns: A valid OAuth2 bearer token string, or `nil` if authentication is not required.
    /// - Throws: ``AccessTokenProviderError`` if the token cannot be fetched or configured properly.
    func getToken() async throws(AccessTokenProviderError) -> String? {
        let now = Date()
        
        // Return cached token if still valid with leeway
        if let token = cachedToken,
           let expiry = tokenExpiry,
           now.addingTimeInterval(expiryLeeway) < expiry
        {
            return token
        }
        
        // Fetch a new token
        let newToken: OAuth2Token
        do {
            newToken = try await tokenRetriever.fetchToken()
        } catch {
            throw AccessTokenProviderError.unableToFetchNewToken(underlying: error)
        }
        
        // Cache the token and return.
        cachedToken = newToken.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(newToken.expires_in))
        return cachedToken
    }
}
