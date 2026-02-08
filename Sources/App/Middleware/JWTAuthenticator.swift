import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit

/// The payload structure for JWT tokens in this application.
///
/// `JWTPayloadData` defines the claims that are embedded in JWT tokens.
/// It implements the standard JWT verification process and includes application-specific claims.
///
/// ## Standard Claims
///
/// - **sub (subject)**: The user's UUID as a string
/// - **exp (expiration)**: Token expiration time as a Unix timestamp
///
/// ## Custom Claims
///
/// - **name**: The user's login name for convenience (avoids needing to look up
///   the user in the database just to get their display name)
///
/// ## Token Validation
///
/// The `verify(using:)` method checks that the token has not expired. Additional
/// validation can be added here if needed (e.g., audience, issuer checks).
struct JWTPayloadData: JWTPayload, Equatable {
    /// JSON coding keys that map Swift property names to JWT claim names.
    ///
    /// - `subject` maps to the standard "sub" claim
    /// - `expiration` maps to the standard "exp" claim
    /// - `userName` maps to a custom "name" claim
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case userName = "name"
    }

    /// The subject claim, containing the user's UUID as a string.
    var subject: SubjectClaim

    /// The expiration claim, indicating when the token is no longer valid.
    var expiration: ExpirationClaim

    /// The user's login name, stored in the token for convenience.
    ///
    /// This allows endpoints to display the user's name without an additional database query.
    var userName: String

    /// Verifies the JWT payload.
    ///
    /// This method is called by JWTKit after decoding and deserializing the JWT.
    /// It checks that the token has not expired and would be a good place to add
    /// additional validation logic (audience, issuer, etc.).
    ///
    /// - Parameter algorithm: The JWT algorithm used to sign the token (provided by the framework)
    ///
    /// - Throws: `JWTError` if the token has expired or other validation fails
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

/// Middleware for authenticating requests using JWT Bearer tokens.
///
/// `JWTAuthenticator` implements `AuthenticatorMiddleware` and validates JWT tokens
/// in the `Authorization: Bearer <token>` header. It's applied to protected routes
/// in the application to ensure requests are authenticated before reaching route handlers.
///
/// ## Authentication Flow
///
/// 1. Extract the Bearer token from the `Authorization` header
/// 2. Parse and verify the JWT signature using the configured key collection
/// 3. Validate the JWT claims (expiration, etc.)
/// 4. Extract user information from the token and create a `User` instance
/// 5. Store the user in the request context for use by route handlers
///
/// ## Error Handling
///
/// Returns 401 Unauthorized for:
/// - Missing Authorization header
/// - Missing or malformed Bearer token
/// - Invalid or expired JWT signature
/// - Invalid user UUID in token subject claim
///
/// All token verification failures are logged at debug level to aid troubleshooting
/// without leaking sensitive information.
///
/// - SeeAlso: ``JWTPayloadData``, ``UserController``
struct JWTAuthenticator: AuthenticatorMiddleware, Sendable {
    /// Type alias for the application request context.
    typealias Context = AppRequestContext

    /// The JWT key collection used to verify token signatures.
    let jwtKeyCollection: JWTKeyCollection

    /// Initializes the authenticator with a JWT key collection.
    ///
    /// - Parameter jwtKeyCollection: The collection of JWT keys used for verification.
    ///   Should contain the same key that was used to sign tokens.
    init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    /// Authenticates a request using JWT Bearer token validation.
    ///
    /// Implements the `AuthenticatorMiddleware.authenticate` method. This is called
    /// by Hummingbird for each request to the protected routes.
    ///
    /// - Parameters:
    ///   - request: The HTTP request containing the Authorization header
    ///   - context: The request context where the authenticated user will be stored
    ///
    /// - Returns: A `User` instance if authentication succeeds, or `nil` if authentication fails.
    ///   This is more commonly done by throwing an error.
    ///
    /// - Throws: `HTTPError(.unauthorized)` if:
    ///   - The Authorization header is missing or malformed
    ///   - The JWT signature is invalid or the token is expired
    ///   - The user UUID in the token subject claim is invalid
    func authenticate(request: Request, context: Context) async throws -> User? {
        // Extract the JWT token from the Authorization: Bearer <token> header
        guard let jwtToken = request.headers.bearer?.token else {
            throw HTTPError(.unauthorized)
        }

        // Verify and decode the JWT token
        let payload: JWTPayloadData
        do {
            payload = try await self.jwtKeyCollection.verify(jwtToken, as: JWTPayloadData.self)
        } catch {
            context.logger.debug("JWT verification failed.")
            throw HTTPError(.unauthorized)
        }

        // Extract user ID from the token subject claim
        guard let userUUID = UUID(uuidString: payload.subject.value) else {
            context.logger.debug("JWT subject is not a valid UUID: \(payload.subject.value)")
            throw HTTPError(.unauthorized)
        }

        // Create a User instance from the token claims
        // Note: passwordHash is nil because we don't store passwords in JWTs
        return User(id: userUUID, name: payload.userName, passwordHash: nil)
    }
}
