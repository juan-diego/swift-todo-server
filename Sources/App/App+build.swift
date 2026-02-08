import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import JWTKit
import Logging

/// A protocol defining the command-line and environment variable arguments required to configure the application.
///
/// This protocol is used across the codebase to abstract over both the real ``AppCommand`` (parsed from CLI)
/// and test implementations, allowing the same ``buildApplication(_:)`` function to work in both contexts.
///
/// - Important: When adding new configuration options:
///   1. Add the property to this protocol
///   2. Add it to ``AppCommand`` in `App.swift`
///   3. Add it to `TestArguments` in your test module
///   4. Update ``ConfigurationManager`` to resolve it
///   5. Update ``buildApplication(_:)`` to wire it in if needed
///
/// - SeeAlso: ``AppCommand``, ``ConfigurationManager``
package protocol AppArguments : Sendable {
    /// The hostname for the server to bind to (e.g., "127.0.0.1" or "0.0.0.0").
    var hostname: String { get }
    
    /// The port for the server to listen on.
    var port: Int { get }
    
    /// The logging level for the application.
    var logLevel: Logger.Level? { get }
    
    /// Optional path to a JSON configuration file to load.
    var configurationFile: String? { get }
}

/// Type alias for the request context used throughout the application.
///
/// This context associates each HTTP request with a Basic Authentication request context
/// that can identify a ``User`` after authentication. This context type is passed to
/// all route handlers and middleware in the application.
typealias AppRequestContext = BasicAuthRequestContext<User>


/// Builds and returns a fully configured Hummingbird application.
///
/// This function orchestrates the application startup process:
/// 1. Sets up logging with the configured level
/// 2. Loads configuration via ``GlobalConfiguration``
/// 3. Builds the router and registers all route groups and middleware
/// 4. Creates the Hummingbird `Application` with the configured address and logger
///
/// ## Error Handling
///
/// Configuration errors (missing project ID, admin password, JWT secret) are surfaced
/// as throwing errors during this phase, preventing the application from starting with
/// incomplete configuration.
///
/// - Parameter arguments: An object conforming to ``AppArguments`` containing all configuration values.
///   Usually this is the parsed ``AppCommand``, but can be a test stub.
///
/// - Returns: A Hummingbird `ApplicationProtocol` instance ready to run.
///
/// - Throws: ``ConfigurationError`` if required configuration is missing, or any errors
///   from the underlying framework during initialization.
func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    
    // Load the configuration
    let appConfiguration = try await GlobalConfiguration.loadConfiguration(fromFile: arguments.configurationFile)
    let configurationManager = ConfigurationManager(appConfiguration: appConfiguration, appArguments: arguments)
    await GlobalConfiguration.store.setLogLevel(configurationManager.logLevel)
    
    // Logger configuration
    let logger = await GlobalConfiguration.newLogger(label: "todo-server")
    
    // Hummingbird configuration
    let router = try await buildRouter(configurationManager)
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "todo-server"
        ),
        logger: logger
    )
    return app
}

/// Builds and returns the application's router with all route groups and middleware.
///
/// The router is organized into three main groups:
///
/// ### User Routes (`/user`)
/// Handles user authentication and JWT token generation using Basic Authentication:
/// - `POST /user`: Login with username and password, returns JWT token
///
/// ### Todo Routes (`/todos`)
/// Handles CRUD operations for todos, protected with JWT authentication:
/// - `GET /todos`: List all todos
/// - `GET /todos/:id`: Get a specific todo
/// - `POST /todos`: Create a new todo
/// - `PATCH /todos/:id`: Update a todo
/// - `DELETE /todos/:id`: Delete a specific todo
/// - `DELETE /todos`: Delete all todos
///
/// ### Auth Test Route (`/auth`)
/// A simple authenticated endpoint to verify JWT tokens:
/// - `GET /auth`: Returns success if the JWT is valid
///
/// ## Middleware Registration
///
/// - Global logging middleware logs all incoming requests at INFO level
/// - User routes use `BasicAuthenticator` to validate username/password credentials
/// - Todo and auth routes use ``JWTAuthenticator`` to validate Bearer tokens
///
/// - Parameter configuration: The resolved configuration and resources needed
///   to build repositories and authentication middleware.
///
/// - Returns: A configured `Router<AppRequestContext>` ready to handle requests.
///
/// - Throws: Any errors during router setup, such as missing JWT secret configuration.
func buildRouter(_ configuration: ConfigurationManager) async throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    
    // Add global middleware
    router.addMiddleware {
        // Log all incoming requests at INFO level
        LogRequestsMiddleware(.info)
    }
    
    // Root endpoint for service health checks
    router.get("/") { _, _ in
        return "todo-server v1.0!"
    }
    
    // Create JWT Key collection and add the HMAC key for signing and verifying JWTs
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(
        hmac: HMACKey(from: configuration.security.jwtSecretKey),
        digestAlgorithm: .sha256,
        kid: JWKIdentifier("auth-jwt")
    )
    
    // MARK: - User Routes (Username/Password Authentication)
    
    // These routes handle user login and JWT token generation
    let userController = UserController(
        jwtKeyCollection: jwtKeyCollection,
        kid: JWKIdentifier("auth-jwt")
    )
    let userRepository = try await UserMemoryRepository(users: configuration.users)
    router.group("user")
        .add(middleware: BasicAuthenticator { username, _ in
            try await userRepository.get(username: username)
        })
        .addRoutes(userController.endpoints)
    
    // MARK: - Todo Routes (JWT Bearer Token Authentication)
    // These routes require a valid JWT Bearer token in the Authorization header
    let todoController = TodoController(repository: try await newTodoRepository(configuration))
    router.group("todos")
        .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
        .addRoutes(todoController.endpoints)
    
    // MARK: - Auth Verification Route
    // A simple endpoint to test JWT authentication without performing any business logic
    router.group("auth")
        .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
        .get("/") { request, context in
            guard let user: User = context.identity else {
                throw HTTPError(.unauthorized)
            }
            return "Authenticated (username: \(user.name))"
        }
    
    return router
}



/// Creates and returns a ``TodoRepository`` based on the configured repository type.
///
/// This factory method uses the configured ``AppRepositoryType`` to determine
/// which repository implementation to instantiate:
/// - `.volatile`: In-memory repository (no external dependencies)
/// - `.persistent`: Firestore with GCP Metadata Service authentication
/// - `.emulated`: Firestore emulator (local development)
///
/// For persistent and emulated repositories, this method calls ``getProjectId()``
/// which validates that a project ID is configured.
///
/// ## Error Handling
///
/// May throw ``ConfigurationError.missedProjectId`` if a persistent or emulated
/// repository is requested but no project ID is configured.
///
/// - Throws: ``ConfigurationError`` if configuration validation fails
///
/// - Returns: A ``TodoRepository`` implementation ready for use
///
/// - SeeAlso: ``AppRepositoryType``, ``TodoRepositoryFactory``
func newTodoRepository(_ configuration: ConfigurationManager) async throws -> TodoRepository {
    let logger = await GlobalConfiguration.logger
    
    var repository: TodoRepository
    switch configuration.repositoryType {
    case .volatile:
        repository = TodoRepositoryFactory.newVolatile()
        logger.info("⚙️ Using the volatile (in-memory) repository.")
    case .persistent:
        repository = try await TodoRepositoryFactory.newPersistent(
            projectId: try configuration.firestoreProjectId,
            tokenRetriever: try configuration.firestoreTokenRetriever
        )
        logger.info("⚙️ Using the persistent Firestore repository.")
    case .emulated:
        repository = try TodoRepositoryFactory.newEmulatedPersistent(projectId: try configuration.firestoreProjectId)
        logger.info("⚙️ Using the Firestore emulator repository.")
    }
    return repository
}
