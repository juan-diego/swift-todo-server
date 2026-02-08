/// A protocol defining the interface for user lookup operations.
///
/// `UserRepository` abstracts user storage, allowing the application to work with
/// different backends (in-memory, databases, LDAP, etc.) without changing authentication logic.
///
/// ## Conformance Requirements
///
/// `UserRepository` conforms to `Sendable`, requiring all implementations to be safe
/// to use across async task boundaries.
///
/// - SeeAlso: ``UserMemoryRepository`` for a simple in-memory implementation
protocol UserRepository: Sendable {
    /// Retrieves a user by their login name.
    ///
    /// This method is called by the Basic Authentication middleware to verify
    /// user credentials during login attempts.
    ///
    /// - Parameter username: The user's login name to look up.
    ///
    /// - Returns: The `User` if found, or `nil` if no user with that username exists.
    ///   The returned user should have a valid `passwordHash` so that password
    ///   verification can be performed by the authentication layer.
    ///
    /// - Throws: Any errors from the underlying storage implementation (database errors,
    ///   network failures, etc.). Authentication failures should return `nil` rather
    ///   than throwing.
    func get(username: String) async throws -> User?
}
