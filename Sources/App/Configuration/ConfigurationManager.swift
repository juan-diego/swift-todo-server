import Foundation
import Logging
import Hummingbird

/// A utility struct for managing application configuration.
///
/// `ConfigurationManager` provides a convenient facade for resolving configuration
/// values from the loaded configuration file and command-line arguments.
///
/// ## Architecture
///
/// - **AppConfiguration**: Decoded configuration file contents
/// - **AppArguments**: Command-line overrides
/// - **ConfigurationError**: Error type thrown when configuration loading or validation fails
///
/// ## Usage
///
/// ```swift
/// let appConfig = try await GlobalConfiguration.loadConfiguration(fromFile: nil)
/// let manager = ConfigurationManager(appConfiguration: appConfig, appArguments: args)
/// let logLevel = manager.logLevel
/// ```
struct ConfigurationManager {
    /// The loaded configuration from disk.
    let appConfiguration: AppConfiguration
    
    /// The parsed command-line arguments.
    let appArguments: AppArguments
    
    /// Resolves the effective log level from CLI, environment, or config file.
    var logLevel: Logger.Level {
        appArguments.logLevel ?? Environment().get("LOG_LEVEL").flatMap {
            Logger.Level(rawValue: $0)
        } ?? appConfiguration.logLevel ?? .info
    }
    
    /// The configured repository type, defaulting to volatile when unspecified.
    var repositoryType: RepositoryType {
        appConfiguration.repository?.type ?? RepositoryType.volatile
    }
    
    /// The configured security settings.
    var security: SecurityConfiguration {
        appConfiguration.security
    }
    
    /// The Firestore-specific repository configuration.
    ///
    /// - Throws: ``ConfigurationError.missedFirestoreConfiguration`` if missing.
    var firestore: FirestoreRepositoryConfiguration {
        get throws {
            guard let firestoreConfig = appConfiguration.repository?.firestore else {
                throw ConfigurationError.missedFirestoreConfiguration("Firestore repository configuration is missing.")
            }
            return firestoreConfig
        }
    }
    
    /// The configured Firestore project ID.
    ///
    /// - Throws: ``ConfigurationError.missedFirestoreConfiguration`` if missing.
    var firestoreProjectId: String {
        get throws {
            try firestore.projectId
        }
    }
    
    /// The configured token retriever strategy for Firestore authentication.
    ///
    /// - Throws: ``ConfigurationError.missedFirestoreConfiguration`` if missing.
    var firestoreTokenRetriever: FirestoreTokenRetrieverType {
        get throws {
            try firestore.tokenRetriever
        }
    }
    
    /// The configured users indexed by username.
    ///
    /// - Throws: Any errors from bcrypt hashing when constructing users.
    var users: [String: User] {
        get async throws {
            var dict = [String: User]()
            for user in appConfiguration.users {
                dict[user.name] = try await User(id: user.id, name: user.name, password: user.password)
            }
            return dict
        }
    }
    
    /// The allowed CORS origin, if configured and valid.
    ///
    /// This validates the configured origin as a URL and logs a warning if it is invalid.
    /// Returning `nil` disables CORS middleware registration.
    ///
    /// - Returns: The allowed origin as a `URL` or `nil` if missing or invalid.
    var corsAllowedOrigin: URL? {
        get async {
            guard let allowedOrigin = appConfiguration.security.cors?.allowOrigin else {
                return nil
            }
            if let url = URL(string: allowedOrigin) {
                return url
            } else {
                await GlobalConfiguration.logger.warning("CORS allowed origin is not a valid URL: \(allowedOrigin)")
                return nil
            }
        }
    }
}
