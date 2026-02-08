import Hummingbird

/// A protocol defining the interface for route controllers.
///
/// Controllers in this application conform to this protocol and provide a collection
/// of route handlers for a specific feature area. Controllers are composed together
/// in ``buildRouter(_:)`` to form the complete API.
///
/// ## Conformances
///
/// Controllers conforming to this protocol should:
/// - Provide a `RouteCollection<AppRequestContext>` containing their routes
/// - Be initialized with any dependencies they need (repositories, clients, etc.)
/// - Keep route handlers thread-safe by using `@Sendable` closures
///
/// - SeeAlso: ``TodoController``, ``UserController``
protocol Controller {
    /// A collection of HTTP routes and handlers for this controller.
    ///
    /// Each route is associated with an HTTP method (GET, POST, PATCH, DELETE)
    /// and a path within the controller's group (e.g., a `TodoController` in the
    /// `todos` group would have routes like `GET /todos`, `POST /todos/:id`).
    var endpoints: RouteCollection<AppRequestContext> { get }
}
