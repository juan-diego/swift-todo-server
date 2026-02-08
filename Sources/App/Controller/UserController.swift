//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import JWTKit

/// Controller for user authentication and JWT token generation.
///
/// `UserController` handles user login via HTTP Basic Authentication and returns
/// a JWT token for subsequent authenticated requests.
///
/// ## Authentication Flow
///
/// 1. Client sends `POST /user` with Basic Authentication header (username:password)
/// 2. Hummingbird middleware validates credentials against the user repository
/// 3. If valid, the authenticated `User` is available in the request context
/// 4. This controller generates a JWT token and returns it in a JSON response
/// 5. Client uses this token in the `Authorization: Bearer <token>` header for future requests
///
/// ## Token Details
///
/// Generated JWTs include:
/// - **Subject (sub)**: The user's UUID
/// - **Username (name)**: The user's login name
/// - **Expiration (exp)**: 12 hours from issuance
/// - **Algorithm**: HMAC with SHA-256
///
/// - SeeAlso: ``JWTAuthenticator``, ``JWTPayloadData``
struct UserController: Controller {
    /// Type alias for the application request context.
    typealias Context = AppRequestContext

    /// The JWT key collection used for signing tokens.
    let jwtKeyCollection: JWTKeyCollection

    /// The key identifier (kid) for the JWT signing key.
    ///
    /// This should match the key ID used when adding the key to `jwtKeyCollection`.
    let kid: JWKIdentifier

    /// Returns the route collection for this controller.
    ///
    /// Defines all HTTP endpoints for user operations.
    var endpoints: RouteCollection<AppRequestContext> {
        return RouteCollection(context: AppRequestContext.self)
            .post(use: login)  // POST /user
    }

    /// Authenticates a user and returns a JWT token.
    ///
    /// This endpoint expects the client to provide HTTP Basic Authentication credentials
    /// (username and password). The authentication is handled by middleware before
    /// reaching this handler. If the credentials are invalid, the middleware returns
    /// a 401 Unauthorized response before this handler is called.
    ///
    /// ## Request Format
    ///
    /// Use HTTP Basic Authentication:
    /// ```
    /// POST /user HTTP/1.1
    /// Authorization: Basic base64(username:password)
    /// ```
    ///
    /// Or via curl:
    /// ```bash
    /// curl -u admin:password http://localhost:8080/user
    /// ```
    ///
    /// ## Response Format
    ///
    /// Returns a JSON object with the JWT token:
    /// ```json
    /// {
    ///   "token": "eyJhbGciOiJIUzI1NiIsImtpZCI6ImF1dGgtand0In0..."
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The HTTP request (unused in this handler)
    ///   - context: The request context containing the authenticated user
    ///
    /// - Returns: A dictionary with a single "token" key containing the JWT string
    ///
    /// - Throws: `HTTPError(.unauthorized)` if no authenticated user is in the context
    ///   (should not occur if middleware is configured correctly), or any JWT signing errors
    @Sendable func login(_ request: Request, context: Context) async throws -> [String: String] {
        // Extract the authenticated user from the request context
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }

        // Create JWT payload with user information and 12-hour expiration
        let payload = JWTPayloadData(
            subject: .init(value: user.id.uuidString),
            expiration: .init(value: Date(timeIntervalSinceNow: 12 * 60 * 60)),
            userName: user.name
        )

        // Sign and return the JWT token
        return try await [
            "token": self.jwtKeyCollection.sign(payload, kid: self.kid)
        ]
    }
}
