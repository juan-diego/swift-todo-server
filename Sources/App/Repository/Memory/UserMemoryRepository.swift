/// A simple in-memory implementation of ``UserRepository``.
///
/// `UserMemoryRepository` stores users in a Swift dictionary keyed by username.
/// It's a value type (struct) suitable for initialization with a fixed set of users.
///
/// ## Use Cases
///
/// - Bootstrap application with a single admin user
/// - Testing authentication logic
/// - Development without a user database
///
/// ## Mutability
///
/// This is an immutable struct. Users cannot be added or removed after initialization.
/// For mutable user storage, a more sophisticated implementation would be needed.
struct UserMemoryRepository: UserRepository {
    /// Dictionary of users keyed by username.
    private let users: [String: User]

    /// Initializes the repository with a fixed set of users.
    ///
    /// - Parameter users: A dictionary mapping usernames to `User` objects.
    ///   Typically initialized with an admin user during application startup.
    init(users: [String: User]) {
        self.users = users
    }

    /// Retrieves a user by username.
    ///
    /// This method performs a simple dictionary lookup. It's used by the Basic Authentication
    /// middleware to find users during login.
    ///
    /// - Parameter username: The login name to look up
    ///
    /// - Returns: The matching `User` if found, or `nil` if not found.
    ///   The returned user should have a valid `passwordHash` for authentication.
    func get(username: String) async throws -> User? {
        self.users[username]
    }
}
