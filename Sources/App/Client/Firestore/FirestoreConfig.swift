import Foundation

/// Configuration for Firestore REST API access.
///
/// `FirestoreConfig` encapsulates the information required to connect to a Firestore
/// database instance via the REST API. This can represent either a production
/// Google Cloud Firestore service or a local emulator instance.
///
/// This struct is intended to be used as a thread-safe, immutable configuration
/// object that can be safely shared across tasks and threads.
///
/// ## Usage Examples
///
/// ```swift
/// // Production (Google Cloud Firestore)
/// let config = FirestoreConfig(projectId: "my-gcp-project")
///
/// // Local emulator running on localhost port 8080
/// let config = FirestoreConfig(
///     projectId: "test-project",
///     apiRoot: URL(string: "http://localhost:8080/v1")!
/// )
///
/// // Custom timeout interval for HTTP requests
/// let config = FirestoreConfig(projectId: "my-gcp-project", timeoutInterval: 10)
/// ```
///
/// - SeeAlso: ``FirestoreHTTPClient``
struct FirestoreConfig: Sendable {
    /// The Google Cloud project ID associated with this Firestore instance.
    ///
    /// This ID is used when constructing Firestore document paths and identifying
    /// the target database. For production use, this should be your actual GCP
    /// project identifier. When connecting to a local emulator, this may be any
    /// arbitrary string as the emulator does not enforce project ID validation.
    ///
    /// Example values:
    /// - `"my-gcp-project"`
    /// - `"test-project"`
    let projectId: String

    /// The base URL for the Firestore REST API endpoint.
    ///
    /// This URL includes the scheme, host, port (if needed), and API version path.
    /// By default, this points to the production Firestore REST API:
    /// `https://firestore.googleapis.com/v1`
    ///
    /// When using a local emulator, this should be set to the emulator’s address
    /// and port, including the `/v1` path, for example:
    /// `http://localhost:8080/v1`
    ///
    /// Make sure the URL ends with the API version path (`/v1`), as this is required
    /// for constructing valid Firestore REST API requests.
    let apiRoot: URL
    
    /// The timeout interval for each HTTP request to the Firestore REST API, in seconds.
    ///
    /// This controls how long the client will wait for a response before timing out.
    /// Defaults to 30 seconds. Adjust this value to accommodate network conditions or
    /// performance requirements.
    let timeoutInterval: TimeInterval

    /// Creates a new Firestore configuration instance.
    ///
    /// - Parameters:
    ///   - projectId: The Google Cloud project ID to use for Firestore document paths.
    ///   - apiRoot: The base Firestore REST API URL, including the API version path.
    ///     Defaults to the production endpoint `https://firestore.googleapis.com/v1`.
    ///   - timeoutInterval: The timeout interval (in seconds) for HTTP requests.
    ///     Default is 30 seconds.
    ///
    /// ## Example: Production configuration
    /// ```swift
    /// let config = FirestoreConfig(projectId: "my-gcp-project")
    /// // apiRoot defaults to https://firestore.googleapis.com/v1
    /// ```
    ///
    /// ## Example: Local emulator configuration
    /// ```swift
    /// let config = FirestoreConfig(
    ///     projectId: "test-project",
    ///     apiRoot: URL(string: "http://localhost:8080/v1")!
    /// )
    /// ```
    ///
    /// ## Example: Custom timeout interval
    /// ```swift
    /// let config = FirestoreConfig(projectId: "my-gcp-project", timeoutInterval: 10)
    /// ```
    ///
    /// - Note: This struct is designed to be thread-safe and is intended to be used
    ///   as an immutable configuration object shared across your application lifetime.
    init(projectId: String, apiRoot: URL = URL(string: "https://firestore.googleapis.com/v1")!, timeoutInterval: TimeInterval = 30) {
        self.projectId = projectId
        self.apiRoot = apiRoot
        self.timeoutInterval = timeoutInterval
    }
}

