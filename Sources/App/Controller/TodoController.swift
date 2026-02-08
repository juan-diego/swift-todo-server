import Foundation
import Hummingbird
import Logging

/// Controller for Todo CRUD operations and listing with optional pagination.
///
/// `TodoController` defines HTTP endpoints under the `/todos` route group. All endpoints require
/// a valid JWT Bearer token and operate only on the authenticated user's todos.
///
/// Responsibilities:
/// - Validate request path/query parameters and JSON bodies
/// - Delegate persistence to the ``TodoRepository`` scoped by user ID
/// - Produce typed responses (`Todo`, ``ControllerPagedResult`` for paginated routes, or HTTP status codes)
///
/// Concurrency:
/// Route handlers are `@Sendable` and safe to use with Hummingbird's async runtime.
///
/// ## Supported Routes
/// - `GET /todos` — List todos (supports `start` and `limit` query parameters for pagination, returns ``ControllerPagedResult``)
/// - `GET /todos/:id` — Fetch a single todo by UUID
/// - `POST /todos` — Create a new todo
/// - `PATCH /todos/:id` — Partially update a todo
/// - `DELETE /todos/:id` — Delete a single todo
/// - `DELETE /todos` — Delete all todos
///
/// - SeeAlso: ``TodoRepository``, ``ControllerPagedResult``, ``buildRouter(_:)``
struct TodoController: Controller {
    /// The repository used for persisting and retrieving todos.
    let repository: any TodoRepository
    
    /// Logger for controller-level diagnostics.
    private let logger = Logger(label: "todo-controller")

    /// Request body for creating a new todo.
    ///
    /// - Parameters:
    ///   - title: Required. The human-readable task description.
    ///   - order: Optional. A sorting hint for displaying todos in a specific order.
    struct CreateRequest: Decodable {
        /// The task description.
        let title: String

        /// Optional ordering value.
        let order: Int?
    }

    /// Request body for updating an existing todo.
    ///
    /// All fields are optional. Only provided fields are updated.
    ///
    /// - Parameters:
    ///   - title: Optional new title
    ///   - order: Optional new order value
    ///   - completed: Optional new completion status
    struct UpdateRequest: Decodable {
        /// New title, or `nil` to leave unchanged.
        let title: String?

        /// New order value, or `nil` to leave unchanged.
        let order: Int?

        /// New completion status, or `nil` to leave unchanged.
        let completed: Bool?
    }

    /// Returns the route collection for this controller.
    ///
    /// Defines all HTTP endpoints handled by this controller and their corresponding
    /// handler methods. The routes assume this controller is mounted at `/todos`.
    /// All routes are expected to be mounted under "/todos" and protected with JWT middleware.
    var endpoints: RouteCollection<AppRequestContext> {
        return RouteCollection(context: AppRequestContext.self)
            .get(":id", use: get)           // GET /todos/:id
            .get(use: list)                 // GET /todos
            .post(use: create)              // POST /todos
            .patch(":id", use: update)      // PATCH /todos/:id
            .delete(":id", use: delete)     // DELETE /todos/:id
            .delete(use: deleteAll)         // DELETE /todos
    }

    /// Retrieves a single todo by its UUID for the authenticated user.
    ///
    /// - Parameters:
    ///   - request: The HTTP request (unused in this handler)
    ///   - context: The request context containing URL parameters and the authenticated user's identity
    ///
    /// - Returns: The matching `Todo` belonging to the authenticated user, or `nil` if not found
    ///   (translates to 404 by the framework if applicable).
    ///
    /// - Throws: `HTTPError(.badRequest)` if the UUID parameter is invalid or the user context is missing,
    ///   or any repository errors.
    @Sendable func get(request: Request, context: AppRequestContext) async throws -> Todo? {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        let id = try context.parameters.require("id", as: UUID.self)
        return try await self.repository.get(userId: userId, id: id)
    }

    /// - Note: This endpoint returns a value conforming to ``PagedResult`` (specifically, ``ControllerPagedResult``), which provides the page items and pagination token in a standardized format for paginated APIs.
    ///
    /// Retrieves a paginated list of todos for the authenticated user.
    ///
    /// This endpoint supports cursor-based pagination using an opaque `start` token and a `limit` on
    /// the number of items per page. It returns a single page of todos wrapped in a ``ControllerPagedResult``
    /// object, which includes the list of todos and an optional `nextPageToken` for fetching subsequent pages.
    ///
    /// - Query Parameters:
    ///   - `start`: An optional opaque pagination token previously obtained from a prior response's
    ///     `nextPageToken` property. When provided, the response will contain the next page of todos starting after this token.
    ///   - `limit`: An optional integer specifying the maximum number of todos to return in the page.
    ///     If omitted, a server-defined default page size is used.
    ///
    /// - Returns: A ``ControllerPagedResult`` (conforming to ``PagedResult``) containing the current page's todos and an optional next page token.
    ///
    /// ## Examples
    ///
    /// Fetch all todos without pagination:
    /// ```http
    /// GET /todos
    /// ```
    ///
    /// Fetch the first 20 todos:
    /// ```http
    /// GET /todos?limit=20
    /// ```
    ///
    /// Fetch the next page using a token:
    /// ```http
    /// GET /todos?start=<nextPageToken>&limit=20
    /// ```
    ///
    /// - Throws: `HTTPError(.badRequest)` if the authenticated user is missing or query parameters are invalid, or any repository errors.
    ///
    /// - SeeAlso: ``ControllerPagedResult``, ``TodoRepository/listPaginated(userId:pageSize:pageToken:)``
    @Sendable func list(request: Request, context: AppRequestContext) async throws -> ControllerPagedResult<Todo> {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        
        var start: String? = nil
        if let startParam = request.uri.queryParameters["start"] {
            start = String(startParam)
        }
        var limit: Int? = nil
        if let limitParam = request.uri.queryParameters["limit"], let intLimit = Int(limitParam) {
            limit = intLimit
        }
        
        if start == nil && limit == nil {
            return ControllerPagedResult(from: try await self.repository.list(userId: userId))
        } else {
            return ControllerPagedResult(from: try await self.repository.listPaginated(userId: userId, pageSize: limit ?? 10, pageToken: start))
        }
    }

    /// Creates a new todo with the provided information for the authenticated user.
    ///
    /// The request body should contain a JSON object with a required `title` field
    /// and an optional `order` field.
    ///
    /// - Parameters:
    ///   - request: The HTTP request containing the JSON body
    ///   - context: The request context containing the authenticated user's identity
    ///
    /// - Returns: An `EditedResponse` containing the newly created todo and a 201 Created status
    ///
    /// - Throws: `HTTPError(.badRequest)` if the request body is invalid JSON or the authenticated user context is missing, or any repository errors.
    ///
    /// - Note: The `url` field of the created todo is constructed using the local development base URL.
    ///
    /// ## Example Request
    ///
    /// ```json
    /// POST /todos
    /// Content-Type: application/json
    ///
    /// {
    ///   "title": "Buy groceries",
    ///   "order": 1
    /// }
    /// ```
    @Sendable func create(request: Request, context: AppRequestContext) async throws
        -> EditedResponse<Todo>
    {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        let request = try await request.decode(as: CreateRequest.self, context: context)
        let todo = try await self.repository.create(
            userId: userId,
            title: request.title,
            order: request.order,
            urlPrefix: "http://localhost:8080/todos/"
        )
        return EditedResponse(status: .created, response: todo)
    }

    /// Updates a todo with the provided values for the authenticated user.
    ///
    /// The request body should contain a JSON object with optional `title`, `order`,
    /// and `completed` fields. Only provided fields are updated.
    ///
    /// - Parameters:
    ///   - request: The HTTP request containing the JSON body
    ///   - context: The request context containing the todo ID parameter and the authenticated user's identity
    ///
    /// - Returns: The updated `Todo` if the item exists and belongs to the user; otherwise throws
    ///   `HTTPError(.badRequest)`.
    ///
    /// - Throws: `HTTPError(.badRequest)` if the todo is not found or the request is invalid,
    ///   or any errors from the repository.
    ///
    /// - Note: Only provided fields are updated; omitted fields remain unchanged.
    ///
    /// ## Example Request
    ///
    /// ```json
    /// PATCH /todos/550e8400-e29b-41d4-a716-446655440000
    /// Content-Type: application/json
    ///
    /// {
    ///   "title": "Updated task",
    ///   "completed": true
    /// }
    /// ```
    @Sendable func update(request: Request, context: AppRequestContext) async throws -> Todo? {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        let id = try context.parameters.require("id", as: UUID.self)
        let request = try await request.decode(as: UpdateRequest.self, context: context)
        guard
            let todo = try await self.repository.update(
                userId: userId,
                id: id,
                title: request.title,
                order: request.order,
                completed: request.completed
            )
        else {
            throw HTTPError(.badRequest)
        }
        return todo
    }

    /// Deletes all todos for the authenticated user.
    ///
    /// This is a destructive operation. All todos belonging to the authenticated user are permanently removed.
    ///
    /// - Parameters:
    ///   - request: The HTTP request (unused in this handler)
    ///   - context: The request context containing the authenticated user's identity
    ///
    /// - Returns: `.ok` on success, `.badRequest` if deletion failed.
    ///
    /// - Throws: Any errors from the repository
    @Sendable func deleteAll(request: Request, context: AppRequestContext) async throws
        -> HTTPResponse.Status
    {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        if try await self.repository.deleteAll(userId: userId) {
            return .ok
        } else {
            return .badRequest
        }
    }

    /// Deletes a single todo by its UUID for the authenticated user.
    ///
    /// - Parameters:
    ///   - request: The HTTP request (unused in this handler)
    ///   - context: The request context containing the todo ID parameter and the authenticated user's identity
    ///
    /// - Returns: `.ok` on success, `.badRequest` if the todo was not found.
    ///
    /// - Throws: Any errors from the repository
    @Sendable func delete(request: Request, context: AppRequestContext) async throws
        -> HTTPResponse.Status
    {
        guard let userId = context.identity?.id.uuidString else {
            throw HTTPError(.badRequest)
        }
        let id = try context.parameters.require("id", as: UUID.self)
        if try await self.repository.delete(userId: userId, id: id) {
            return .ok
        } else {
            return .badRequest
        }
    }
}
