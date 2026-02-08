import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A token retriever that fetches tokens from the GCP metadata server.
///
/// `MetadataServerTokenRetriever` is designed for applications running on GCP infrastructure
/// (App Engine, Cloud Run, Compute Engine, etc.) that can access the GCP metadata server.
/// This provider automatically obtains tokens using the instance's service account credentials.
///
/// ## How It Works
///
/// When `fetchToken()` is called:
/// 1. Makes a request to the GCP metadata server endpoint
/// 2. Requests tokens with the specified scope (default Firestore scope)
/// 3. Returns the access token with expiration information
///
/// ## GCP Integration
///
/// This provider is designed to work seamlessly with GCP infrastructure:
/// - Automatically discovers the metadata server URL
/// - Uses the instance's service account for authentication
/// - Respects GCP IAM permissions and scopes
///
/// ## Use Cases
///
/// - Production applications running on GCP infrastructure
/// - Applications that require automatic service account token acquisition
/// - Serverless deployments (Cloud Functions, Cloud Run)
///
/// ## Configuration
///
/// The provider uses the default metadata server URL:
/// - Base: http://metadata/computeMetadata/v1
/// - Endpoint: /instance/service-accounts/default/token
///
/// Custom URL can be provided if needed.
///
/// - SeeAlso: ``AppDefaultCredentialsTokenRetriever``, ``FirestoreHTTPClient``
struct MetadataServerTokenRetriever: TokenRetriever {
    /// Base URL for the metadata server.
    private let metadataBaseURL: URL
    /// Optional OAuth2 scope to request.
    private let scope: String?
    /// URL session used for network requests.
    private let urlSession: URLSession
    /// Creates a provider that reads tokens from the GCP metadata server.
    ///
    /// - Parameters:
    ///   - metadataBaseURL: Base URL for the metadata server API.
    ///   - scope: OAuth2 scope to request from the metadata server.
    ///   - urlSession: Session used to perform network requests.
    init(
        metadataBaseURL: URL = URL(string: "http://metadata/computeMetadata/v1")!,
        scope: String? = "https://www.googleapis.com/auth/datastore",
        urlSession: URLSession = .shared
    ) {
        self.metadataBaseURL = metadataBaseURL
        self.scope = scope
        self.urlSession = urlSession
    }
    /// Fetches a new OAuth2 token from the GCP metadata server.
    ///
    /// This method constructs and sends a request to the GCP metadata server to obtain
    /// an access token for Firestore authentication. The metadata server handles
    /// the service account credential acquisition automatically.
    ///
    /// - Returns: An `OAuth2Token` containing the new access token and expiration data.
    /// - Throws: ``TokenFetchingError`` if the metadata server request fails or returns an error.
    func fetchToken() async throws(TokenFetchingError) -> OAuth2Token {
        let endpointPath = "/instance/service-accounts/default/token"
        guard var components = URLComponents(url: metadataBaseURL, resolvingAgainstBaseURL: false) else {
            throw TokenFetchingError.invalidConfiguration(message: "Invalid metadata base URL: \(metadataBaseURL)")
        }
        components.path += endpointPath
        if let scope {
            components.queryItems = [
                URLQueryItem(name: "scopes", value: scope)
            ]
        }
        guard let url = components.url else {
            throw TokenFetchingError.invalidConfiguration(message: "Invalid request URL: \(components.string ?? components.path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        // Required by the metadata server to allow access.
        request.setValue("Google", forHTTPHeaderField: "Metadata-Flavor")
        
        return try await submitTokenRequest(to: urlSession, with: request)
    }
}
