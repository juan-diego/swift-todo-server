import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Models the Application Default Credentials format.
///
/// This struct represents the standard GCP Application Default Credentials file format,
/// which includes client ID, client secret, refresh token, and type information.
/// It's used to configure the token fetching process for local development environments.
struct ApplicationDefaultCredentials: Decodable, Sendable {
    /// OAuth client ID.
    let client_id: String
    /// OAuth client secret.
    let client_secret: String
    /// Refresh token used to obtain access tokens.
    let refresh_token: String
    /// Credential type (expected to be "authorized_user").
    let type: String
}
/// A token retriever that fetches tokens using Application Default Credentials.
///
/// `AppDefaultCredentialsTokenRetriever` is designed for local development environments
/// where Application Default Credentials are available (typically in the ~/.config/gcloud/
/// directory). This provider uses the refresh token to obtain new access tokens when needed.
///
/// ## Configuration
///
/// The provider will look for credentials in the following order:
/// 1. Explicit path provided via `credentialsPath` parameter
/// 2. Path specified in the `GOOGLE_APPLICATION_CREDENTIALS` environment variable
/// 3. Default location: ~/.config/gcloud/application_default_credentials.json
///
/// ## Token Acquisition Process
///
/// When `fetchToken()` is called:
/// 1. Loads credentials from the configured source
/// 2. Makes a request to Google's OAuth2 token endpoint using refresh token
/// 3. Returns the newly acquired access token with expiration info
///
/// ## Use Cases
///
/// - Local development with GCP service account credentials
/// - Testing Firestore applications in development environments
/// - Running applications outside of GCP but with proper credential setup
///
/// ## Security Considerations
///
/// - Credentials files should be protected with appropriate file permissions
/// - Refresh tokens provide long-term access and should be handled securely
///
/// - SeeAlso: ``MetadataServerTokenRetriever``, ``FirestoreHTTPClient``
struct AppDefaultCredentialsTokenRetriever: TokenRetriever {
    
    /// Type alias for the parsed credentials format.
    typealias Credentials = ApplicationDefaultCredentials
    
    /// URL session used for network requests.
    private let urlSession: URLSession
    /// Loaded credentials used to exchange refresh tokens for access tokens.
    private var credentials: Credentials
    
    /// Creates a token retriever for Application Default Credentials.
    ///
    /// - Parameters:
    ///   - credentialsPath: Optional explicit path to credentials JSON file.
    ///     If `nil`, uses `GOOGLE_APPLICATION_CREDENTIALS` or default location.
    ///   - scope: OAuth2 scope to request (defaults to Firestore scope).
    ///   - urlSession: URL session for network requests.
    init(
        credentialsPath: String? = nil,
        scope: String = "https://www.googleapis.com/auth/datastore",
        urlSession: URLSession = .shared
    ) throws {
        self.urlSession = urlSession
        self.credentials = try Self.loadCredentials(credentialsPath: credentialsPath, scope: scope, urlSession: urlSession)
    }
    
    /// Fetches a new OAuth2 token using Application Default Credentials.
    ///
    /// This method performs the following steps:
    /// 1. Constructs a token request to Google's OAuth2 endpoint
    /// 2. Uses the refresh token from Application Default Credentials to obtain a new access token
    /// 3. Returns the token with expiration information
    ///
    /// - Returns: An `OAuth2Token` containing the new access token and expiration data.
    /// - Throws: ``TokenFetchingError`` if credentials cannot be loaded or token exchange fails.
    func fetchToken() async throws(TokenFetchingError) -> OAuth2Token {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": credentials.client_id,
            "client_secret": credentials.client_secret,
            "refresh_token": credentials.refresh_token,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        return try await submitTokenRequest(to: urlSession, with: request)
    }
    
    // MARK: - Private Helpers
    /// Loads Application Default Credentials from a file.
    ///
    /// This method searches for credentials in the specified path or default locations,
    /// validates that they are of type "authorized_user", and returns the parsed credentials.
    ///
    /// - Parameters:
    ///   - credentialsPath: Optional explicit path to credentials JSON file.
    ///   - scope: OAuth2 scope to request (defaults to Firestore scope).
    ///   - urlSession: URL session for network requests.
    /// - Returns: A parsed `ApplicationDefaultCredentials` object.
    /// - Throws: ``TokenFetchingError.invalidConfiguration`` if credentials file cannot be loaded or parsed.
    private static func loadCredentials(credentialsPath: String?, scope: String, urlSession:  URLSession) throws -> Credentials {
        let path: String
        
        if let explicitPath = credentialsPath {
            path = explicitPath
        } else if let envPath = ProcessInfo.processInfo.environment["GOOGLE_APPLICATION_CREDENTIALS"] {
            path = envPath
        } else {
            // Default Application Default Credentials location
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            path = homeDir
                .appendingPathComponent(".config")
                .appendingPathComponent("gcloud")
                .appendingPathComponent("application_default_credentials.json")
                .path
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw TokenFetchingError.invalidConfiguration(message: "Credentials file not found at '\(path)'.")
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw TokenFetchingError.invalidConfiguration(
                message: "Failed to read credentials file at '\(path)': \(error.localizedDescription)"
            )
        }
        
        let decoder = JSONDecoder()
        
        // Try parsing as Application Default Credentials first
        if let adc = try? decoder.decode(ApplicationDefaultCredentials.self, from: data),
           adc.type == "authorized_user"
        {
            return adc
        }
        throw TokenFetchingError.invalidConfiguration(message: "Unsupported credentials format at '\(path)'.")
    }
    
}
