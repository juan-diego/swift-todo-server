import HummingbirdBcrypt
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import NIOPosix

/// A user account in the application.
///
/// `User` represents an authenticated principal in the system. It conforms to the
/// `PasswordAuthenticatable` protocol from Hummingbird, allowing it to be used
/// directly with basic HTTP authentication and JWT token generation.
///
/// ## Concurrency Safety
///
/// This class is marked `final` and conforms to `Sendable`, making it safe to
/// share across async task boundaries and throughout the application.
///
/// ## Password Hashing
///
/// Passwords are never stored in plaintext. Instead, they are hashed using bcrypt
/// (cost factor 12) via the NIOThreadPool to avoid blocking the event loop during
/// the computationally expensive hashing operation.
///
/// ## Security Considerations
///
/// - Passwords are always hashed before storage
/// - The `passwordHash` field may be `nil` for programmatically created users
///   (e.g., those deserialized from persistent storage)
/// - Never log or expose password hashes
final class User: PasswordAuthenticatable, Sendable {

    /// Unique identifier for this user.
    ///
    /// Typically a UUID, used in JWT subject claims and for referencing the user
    /// in databases and logs.
    let id: UUID

    /// The user's login name.
    ///
    /// Used for Basic Authentication credentials and displayed in authenticated responses.
    let name: String

    /// The bcrypt-hashed password for this user.
    ///
    /// `nil` if the user was deserialized from storage without a password,
    /// or if the user is constructed without setting a hash.
    let passwordHash: String?

    /// Creates a user with explicit values, without hashing a password.
    ///
    /// This initializer is used when loading users from persistent storage or
    /// when programmatically constructing user instances that already have a hashed password.
    ///
    /// - Parameters:
    ///   - id: The user's unique identifier.
    ///   - name: The user's login name.
    ///   - passwordHash: The bcrypt-hashed password, or `nil` if not available.
    init(id: UUID, name: String, passwordHash: String?) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
    }

    /// Creates a user and hashes the provided plaintext password.
    ///
    /// The password is hashed asynchronously using the NIOThreadPool to avoid
    /// blocking the event loop. This initializer is typically used during user
    /// creation or account setup.
    ///
    /// ## Performance Considerations
    ///
    /// Password hashing is computationally expensive (bcrypt cost 12). Calling this
    /// initializer will block a thread pool thread for a short time. Only call during
    /// initialization or user creation, not in hot request paths.
    ///
    /// - Parameters:
    ///   - id: The user's unique identifier.
    ///   - name: The user's login name.
    ///   - password: The plaintext password to hash. Should be validated for strength
    ///     and length before passing to this initializer.
    ///
    /// - Throws: Any errors from the NIOThreadPool or bcrypt hashing operation.
    init(id: UUID, name: String, password: String) async throws {
        self.id = id
        self.name = name
        self.passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(password, cost: 12)
        }
    }
}

/// Extension providing the `PasswordAuthenticatable` protocol requirement.
///
/// The `username` property is required by the Hummingbird authentication middleware.
/// It is implemented as an alias to the `name` property.
extension User {
    /// The username for Basic Authentication purposes.
    ///
    /// This property is required by the `PasswordAuthenticatable` protocol
    /// and simply returns the user's `name`.
    var username: String { self.name }
}
