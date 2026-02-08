import ArgumentParser
import Hummingbird
import Logging

/// The main entry point for the ToDo Server application.
///
/// `AppCommand` is marked with `@main` to serve as the program's entry point. It uses
/// `AsyncParsableCommand` from the `ArgumentParser` library to parse command-line arguments
/// and environment configuration.
///
/// ## Supported Arguments
///
/// - `--hostname` or `-h`: Server bind address (default: "127.0.0.1")
/// - `--port` or `-p`: Server port (default: 8080)
/// - `--log-level` or `-l`: Logging level (optional, defaults to INFO)
/// - `--repository-type`: Storage backend type: "volatile" (in-memory), "persistent" (Firestore),
///   or "emulated" (Firestore emulator)
/// - `--project-id`: Google Cloud project ID (required for persistent/emulated repositories)
/// - `--admin-user-name`: Admin user login name (defaults to "admin")
/// - `--admin-user-password`: Admin user password (required)
/// - `--jwt-secret-key`: Secret key for JWT signing (required)
/// - `--development`: Enables development configuration settings (for local testing and debugging)
///
/// ## Environment Variables
///
/// Command-line arguments can also be provided via environment variables if preferred:
/// - `HOSTNAME`
/// - `PORT`
/// - `LOG_LEVEL`
/// - `REPOSITORY_TYPE`
/// - `PROJECT_ID`
/// - `ADMIN_USER_NAME`
/// - `ADMIN_USER_PASSWORD`
/// - `JWT_SECRET_KEY`
/// - `DEVELOPMENT`
///
/// Command-line arguments take precedence over environment variables.
///
/// ## Execution Flow
///
/// 1. Parse command-line arguments into `AppCommand` properties
/// 2. Build the Hummingbird application via ``buildApplication(_:)``
/// 3. Start the async service listener on the configured host and port
@main
struct AppCommand: AsyncParsableCommand, AppArguments {
    /// The hostname to bind the server to.
    @Option(name: .shortAndLong, help: "The hostname or IP address to bind the server to (default: 127.0.0.1). May also be set via the HOSTNAME environment variable.")
    var hostname: String = "127.0.0.1"

    /// The port to bind the server to.
    @Option(name: .shortAndLong, help: "The port number the server will listen on (default: 8080). May also be set via the PORT environment variable.")
    var port: Int = 8080

    /// The logging level for the application.
    ///
    /// If not specified, the application defaults to `.info` level logging.
    @Option(name: .shortAndLong, help: "Set the logging level (debug, info, warning, error). Defaults to info. May also be set via the LOG_LEVEL environment variable.")
    var logLevel: Logger.Level?
    
    /// Optional path to a JSON configuration file to load.
    @Option(name: .shortAndLong, help: "Path to the optional configuration file. If not set, the application loads the default configuration file.")
    var configurationFile: String?

    /// Runs the application with the parsed command-line arguments.
    ///
    /// This method is called automatically when the program starts. It initializes
    /// the Hummingbird application and starts listening for incoming requests.
    ///
    /// - Throws: Any configuration or startup errors that prevent the application
    ///   from initializing.
    func run() async throws {
        let app = try await buildApplication(self)
        try await app.runService()
    }
}

/// Extends `Logger.Level` to conform to `ExpressibleByArgument`.
///
/// This enables the `ArgumentParser` library to automatically parse logging level strings
/// (e.g., "debug", "info", "warning", "error") from the command line into `Logger.Level` enum values.
///
/// The extension uses Swift 6's conditional attribute syntax (`RetroactiveAttribute`) when
/// available to mark the conformance as retroactive, otherwise uses a standard extension.
#if hasFeature(RetroactiveAttribute)
    extension Logger.Level: @retroactive ExpressibleByArgument {}
#else
    extension Logger.Level: ExpressibleByArgument {}
#endif
