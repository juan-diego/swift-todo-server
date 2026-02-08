import Foundation
import Logging

/// A factory for creating ``TodoRepository`` instances of different types.
///
/// `TodoRepositoryFactory` provides static methods to construct different implementations
/// of the `TodoRepository` protocol based on the desired persistence strategy:
/// - Volatile (in-memory) for testing or development
/// - Persistent (Google Cloud Firestore) for production
/// - Emulated (local Firestore emulator) for development and testing
///
/// The factory pattern allows the choice of repository implementation to be deferred
/// until runtime, based on configuration values.
///
/// Configuration values in ``ConfigurationManager`` determine which repository
/// implementation is constructed at runtime.
struct TodoRepositoryFactory {
    
    /// Creates an in-memory todo repository that does not persist data.
    ///
    /// This volatile repository stores all todos in a Swift dictionary and loses
    /// all data when the application stops. It's suitable for:
    /// - Testing route handlers
    /// - Development without infrastructure setup
    /// - Demos and prototypes
    ///
    /// - Returns: A new ``TodoMemoryRepository`` instance with empty storage.
    static func newVolatile() -> TodoMemoryRepository {
        return TodoMemoryRepository()
    }
    
    /// Creates a Firestore-backed todo repository connected to Google Cloud.
    ///
    /// This repository uses the Google Cloud Metadata Service to obtain OAuth2 tokens
    /// for authentication, making it suitable for production deployments on GCP infrastructure
    /// (App Engine, Cloud Run, Compute Engine, etc.).
    ///
    /// ## Prerequisites
    ///
    /// - The application must be running on GCP infrastructure with appropriate service account permissions.
    /// - The service account must have Firestore read/write permissions.
    /// - The Google Cloud project ID must be provided and valid.
    /// - The configured ``FirestoreTokenRetrieverType`` controls whether to use
    ///   Application Default Credentials or the GCP Metadata Service.
    ///
    /// - Parameter projectId: The Google Cloud project ID (e.g., "my-gcp-project")
    /// - Parameter tokenRetriever: Strategy for fetching Firestore access tokens.
    ///
    /// - Returns: A new ``TodoFirestoreRepository`` configured for production Firestore access.
    static func newPersistent(projectId : String, tokenRetriever: FirestoreTokenRetrieverType) async throws -> TodoFirestoreRepository {
        let logger = await GlobalConfiguration.logger
        
        let tokenProvider : AccessTokenProvider
        switch tokenRetriever {
        case .None:
            throw ConfigurationError.invalidConfiguration(
                "Firestore token retriever is set to 'None'. Use 'AppDefaultCredentials' or 'MetadataServer'."
            )
        case .AppDefaultCredentials:
            tokenProvider = CachedAccessTokenProvider(tokenRetriever: try AppDefaultCredentialsTokenRetriever())
            logger.info("⚙️ Using Application Default Credentials for Firestore authentication.")
        case .MetadataServer:
            tokenProvider = CachedAccessTokenProvider(tokenRetriever: MetadataServerTokenRetriever())
            logger.info("⚙️ Using the metadata server for Firestore authentication.")
        }
        
        let firestoreConfig = FirestoreConfig(projectId: projectId)
        let firestoreHTTPClient = FirestoreHTTPClient(
            config: firestoreConfig,
            tokenProvider: tokenProvider
        )
        return TodoFirestoreRepository(httpClient: firestoreHTTPClient, config: firestoreConfig)
    }
    
    /// Creates a Firestore-backed repository connected to a local Firestore emulator.
    ///
    /// This repository is configured to connect to a local Firestore emulator instance,
    /// typically running on `http://localhost:8080`. No authentication is required.
    ///
    /// This mode is ideal for:
    /// - Local development without GCP infrastructure
    /// - Integration testing with persistent storage semantics
    /// - Pre-production validation
    ///
    /// ## Setup
    ///
    /// Before using this, ensure the Firestore emulator is running:
    /// ```bash
    /// gcloud beta emulators firestore start
    /// ```
    ///
    /// - Parameter projectId: A project ID to use with the emulator (can be arbitrary for testing)
    ///
    /// - Returns: A new ``TodoFirestoreRepository`` configured for emulator access.
    static func newEmulatedPersistent(projectId: String) throws -> TodoFirestoreRepository {
        let firestoreConfig = FirestoreConfig(
            projectId: projectId,
            apiRoot: URL(string: "http://localhost:8080/v1")!
        )
        let tokenProvider = NoAuthAccessTokenProvider()
        let firestoreHTTPClient = FirestoreHTTPClient(
            config: firestoreConfig,
            tokenProvider: tokenProvider
        )
        return TodoFirestoreRepository(httpClient: firestoreHTTPClient, config: firestoreConfig)
    }
}
