import Foundation
import Logging
import Hummingbird

/// Shared configuration utilities and state for application-wide settings.
struct GlobalConfiguration {
    /// Shared actor-backed store for configuration state.
    static let store = ConfigurationStore()
    
    /// A lazily initialized logger that respects the configured log level.
    static var logger: Logger {
        get async {
            // Check if the logger already exists.
            if let logger = await store.logger {
                return logger
            }
            // Store a new logger and return it.
            let logger = await newLogger(label: "Configuration")
            await store.setLogger(logger)
            return logger
        }
    }
    
    /// Creates a new logger configured with the current global log level.
    ///
    /// - Parameter label: The logger label to use.
    /// - Returns: A configured `Logger` instance.
    static func newLogger(label: String) async -> Logger {
        var logger = Logger(label: label)
        logger.logLevel = await store.logLevel
        return logger
    }
    
    /// Loads application configuration from disk.
    ///
    /// The configuration file path is resolved in this order:
    /// 1. The explicit `configurationFile` argument.
    /// 2. The `CONFIGURATION_FILE` environment variable.
    /// 3. The default `./config.json` path.
    ///
    /// - Parameter configurationFile: Optional configuration file path override.
    /// - Returns: The decoded ``AppConfiguration``.
    /// - Throws: ``ConfigurationError`` if the file cannot be found or decoded.
    static func loadConfiguration(fromFile configurationFile: String? = nil) async throws -> AppConfiguration {
        let configFile = configurationFile ?? Environment().get("CONFIGURATION_FILE") ?? "./config.json"
        
        // Find the first available URL.
        var configurationURL: URL?
        if FileManager.default.fileExists(atPath: configFile) {
            configurationURL = URL(fileURLWithPath: configFile)
        }
        
        // Load the configuration.
        guard let resolvedUrl = configurationURL else {
            throw ConfigurationError.missedConfiguration("Configuration file not found at path '\(configFile)'.")
        }
        do {
            let data = try Data(contentsOf: resolvedUrl)
            let configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
            await logger.info("Loaded configuration from '\(resolvedUrl.path())'.")
            return configuration
        } catch {
            throw ConfigurationError.invalidConfiguration("Failed to decode configuration file at '\(resolvedUrl.path())'.", error: error)
        }
    }
}

/// Actor-backed storage for shared configuration values.
actor ConfigurationStore {
    /// The configured logging level for the application.
    private var storedLogLevel: Logger.Level = .info
    
    /// The cached shared logger instance.
    private var storedLogger: Logger?
    
    /// Returns the currently configured logging level.
    var logLevel: Logger.Level {
        get async {
            storedLogLevel
        }
    }
    
    /// Updates the logging level used by new loggers.
    ///
    /// - Parameter level: The new log level to apply.
    func setLogLevel(_ level: Logger.Level) async {
        storedLogLevel = level
    }
    
    /// Returns the cached logger instance if one has been created.
    var logger: Logger? {
        get async {
            storedLogger
        }
    }
    
    /// Stores the shared logger instance.
    ///
    /// - Parameter logger: The logger to cache.
    func setLogger(_ logger: Logger) async {
        storedLogger = logger
    }
}
