import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A representation of an OAuth2 token response.
///
/// This struct represents the standard OAuth2 token response format that includes:
/// - The access token string
/// - Token expiration time (in seconds)
/// - The token type (usually "Bearer")
struct OAuth2Token: Decodable, Sendable {
    /// The bearer access token string.
    let access_token: String
    /// The token lifetime in seconds.
    let expires_in: Int
    /// The token type, typically "Bearer".
    let token_type: String
}

/// Errors that can occur when fetching OAuth2 tokens.
///
/// These errors cover various failure scenarios in the token fetching process:
/// - Configuration issues (invalid credentials, missing scopes)
/// - Network connectivity problems
/// - Authentication failures (401/403 responses)
/// - Server errors (5xx responses)
/// - Token exchange failures (invalid grant types, expired refresh tokens)
/// - Decoding errors when parsing token responses
enum TokenFetchingError: Error, Sendable {
    /// Indicates an invalid configuration that prevents token fetching.
    case invalidConfiguration(message: String)
    /// Indicates that the request was unauthorized (401/403).
    case unauthorized(message: String?)
    /// Indicates a server error (5xx status codes) during token fetch.
    case serverError(statusCode: Int, message: String?)
    /// Indicates a failure during the token exchange process.
    case tokenExchangeFailed(statusCode: Int, message: String?)
    /// Indicates a network error occurred during the fetch.
    case networkError(underlying: Error)
    /// Indicates a decoding error when parsing the token response.
    case decodingError(underlying: Error)
}

/// A protocol defining how to fetch OAuth2 tokens for Firestore authentication.
///
/// The `TokenRetriever` protocol provides a standardized interface for fetching
/// OAuth2 tokens from various sources, including:
/// - GCP Metadata Server (for GCP-hosted applications)
/// - Application Default Credentials (for local development)
/// - Custom token sources
///
/// Implementations of this protocol handle the specific mechanics of token acquisition
/// while providing a consistent interface for the authentication system.
protocol TokenRetriever: Sendable {
    /// Fetches a new OAuth2 token from the source.
    ///
    /// - Returns: An `OAuth2Token` containing the token data and expiration.
    /// - Throws: ``TokenFetchingError`` if the token cannot be fetched due to various reasons.
    func fetchToken() async throws(TokenFetchingError) -> OAuth2Token
}

// MARK: - Extensions
extension TokenRetriever {
    /// Submits a token request to the specified URLSession and processes the response.
    ///
    /// This helper method handles the common network request and response processing
    /// logic for token fetching operations, including:
    /// - Network request handling
    /// - HTTP status code validation
    /// - Response body parsing
    /// - Error translation to appropriate token fetching errors
    ///
    /// - Parameters:
    ///   - urlSession: The URLSession to use for the network request.
    ///   - request: The URLRequest to send for token fetching.
    /// - Returns: An `OAuth2Token` if the request was successful.
    /// - Throws: ``TokenFetchingError`` if the request failed or returned an error status.
    ///
    /// - Note: This method is primarily used by concrete implementations of `TokenRetriever`.
    func submitTokenRequest(to urlSession: URLSession, with request: URLRequest) async throws(TokenFetchingError) -> OAuth2Token {
        let data: Data
        let response: URLResponse
       
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw TokenFetchingError.networkError(underlying: error)
        }
       
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenFetchingError.serverError(
                statusCode: -1,
                message: "Received a non-HTTP response."
            )
        }
       
        let statusCode = httpResponse.statusCode
       
        guard (200...299).contains(statusCode) else {
            let message: String?
            if let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty {
                message = bodyString
            } else {
                message = nil
            }
            switch statusCode {
            case 401, 403:
                throw TokenFetchingError.unauthorized(message: message)
            default:
                throw TokenFetchingError.serverError(statusCode: statusCode, message: message)
            }
        }
       
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(OAuth2Token.self, from: data)
        } catch {
            throw TokenFetchingError.decodingError(underlying: error)
        }
    }
}
