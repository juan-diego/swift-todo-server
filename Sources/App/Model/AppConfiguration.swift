import Foundation
import Logging

/// Top-level application configuration loaded from `config.json`.
struct AppConfiguration: Codable, Sendable {
    /// The default log level for the application.
    let logLevel: Logger.Level?
    /// Optional Hummingbird server configuration overrides.
    let hummingbird: HummingbirdConfiguration?
    /// Security-related settings, including JWT secrets.
    let security: SecurityConfiguration
    /// Repository configuration including persistence type and Firestore settings.
    let repository: RepositoryConfiguration?
    /// The set of configured users.
    let users: [AppConfigurationUser]
}

/// Configuration overrides for the Hummingbird server.
struct HummingbirdConfiguration: Codable, Sendable {
    /// Optional hostname override.
    let hostName: String?
    /// Optional port override.
    let port: Int?
}

/// Security configuration values.
struct SecurityConfiguration: Codable, Sendable {
    /// Secret key used to sign and verify JWTs.
    let jwtSecretKey: String
}

/// Configuration for selecting and configuring the repository backend.
struct RepositoryConfiguration: Codable, Sendable {
    /// The repository type to use for persistence.
    let type: RepositoryType
    /// Firestore configuration used for persistent or emulated modes.
    let firestore: FirestoreRepositoryConfiguration?
}

/// Supported repository types in configuration.
enum RepositoryType: String, Codable, Sendable {
    /// In-memory, volatile storage.
    case volatile
    /// Local Firestore emulator storage.
    case emulated
    /// Production Firestore storage.
    case persistent
}

/// Configuration values required to connect to Firestore.
struct FirestoreRepositoryConfiguration: Codable, Sendable {
    /// The Firestore project ID.
    let projectId: String
    /// The token retriever strategy to use.
    let tokenRetriever: FirestoreTokenRetrieverType
}

/// Supported token retriever strategies in configuration.
enum FirestoreTokenRetrieverType: String, Codable, Sendable {
    /// No authentication token is used.
    case None
    /// Use the GCP metadata server to obtain tokens.
    case MetadataServer
    /// Use Application Default Credentials to obtain tokens.
    case AppDefaultCredentials
}

/// User definition in the configuration file.
struct AppConfigurationUser: Codable {
    /// The user's unique identifier.
    let id: UUID
    /// The user's login name.
    let name: String
    /// The user's plaintext password from configuration.
    let password: String
}
