import Foundation

/// A protocol defining the interface for todo storage and retrieval operations scoped to a single authenticated user.
///
/// `TodoRepository` abstracts the persistence layer, allowing the application to work
/// with different storage backends (in-memory, Firestore, etc.) without changing business logic.
///
/// All CRUD operations are always scoped to todos belonging to a single authenticated user,
/// identified by the `userId` parameter.
///
/// All methods are `async throws`, reflecting the potentially long-lived I/O operations
/// involved in database access. Implementations may access network services, databases,
/// or local storage, all of which can fail.
///
/// ## Conformance Requirements
///
/// `TodoRepository` conforms to `Sendable`, requiring all implementations to be safe
/// to use across async task boundaries. Implementations should use actors or other
/// concurrency-safe patterns if they maintain mutable state.
///
/// - SeeAlso: ``TodoMemoryRepository`` for an in-memory implementation,
///   ``TodoFirestoreRepository`` for a Firestore-backed implementation
///
/// - Note: The `listPaginated(userId:pageSize:pageToken:)` method returns a value conforming to ``PagedResult`` (specifically, ``RepositoryPagedResult``), which provides a type-safe, generic representation of paginated query results. All implementations guarantee that the returned value supports the `PagedResult` interface for inspecting items and pagination tokens.
protocol TodoRepository: Sendable {
    /// Creates a new todo with the provided information for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - title: The human-readable name of the task.
    ///   - order: An optional integer for ordering todos in lists.
    ///   - urlPrefix: The base URL path (e.g., `http://localhost:8080/todos/`) to which
    ///     the todo's UUID will be appended to form the complete URL.
    ///
    /// - Returns: The newly created `Todo` with a generated UUID and populated URL.
    ///
    /// - Throws: Any errors from the underlying storage implementation (network errors,
    ///   authentication failures, database errors, etc.).
    func create(userId: String, title: String, order: Int?, urlPrefix: String)
        async throws -> Todo

    /// Retrieves a single todo by its unique identifier for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - id: The UUID of the todo to retrieve.
    ///
    /// - Returns: The `Todo` if found among the specified user's todos, or `nil` if no todo with that ID exists for that user.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    func get(userId: String, id: UUID) async throws -> Todo?

    /// Retrieves all todos for the specified user from storage.
    ///
    /// - Parameter userId: The unique identifier of the authenticated user whose todos are being retrieved.
    ///
    /// - Returns: An array of all todos for the specified user. Returns an empty array if no todos exist for that user.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    func list(userId: String) async throws -> [Todo]

    /// Retrieves a paginated list of todos for the specified user.
    ///
    /// Pagination allows efficient retrieval of large result sets by fetching data in
    /// manageable pages using a cursor-based approach. This method returns a single page
    /// of todos along with a cursor token for the next page, or `nil` if there are no more results.
    ///
    /// The returned value conforms to ``PagedResult``, allowing generic handling of paginated results across repository implementations.
    ///
    /// The returned type is ``RepositoryPagedResult``, encapsulating the list of todos
    /// for the current page and an optional cursor token for fetching subsequent pages.
    ///
    /// Implementations provide consistent cursor-based pagination semantics across all repository types.
    ///
    /// ## Usage Pattern
    ///
    /// ```swift
    /// var allTodos: [Todo] = []
    /// var pageToken: String? = nil
    ///
    /// repeat {
    ///     let page = try await repository.listPaginated(
    ///         userId: "user123",
    ///         pageSize: 20,
    ///         pageToken: pageToken
    ///     )
    ///     allTodos.append(contentsOf: page.items)
    ///     pageToken = page.nextPageToken
    /// } while pageToken != nil
    /// ```
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are being paginated.
    ///   - pageSize: Maximum number of todos to return per page (1-100).
    ///     Implementations may clamp this value. Defaults to 10.
    ///   - pageToken: Optional token from a previous response for fetching
    ///     the next page. Pass `nil` to start from the beginning.
    ///
    /// - Returns: A ``RepositoryPagedResult`` (conforming to ``PagedResult``) representing a page of todos
    ///   for the specified user, including the current page's items and an optional cursor token for the next page.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    ///
    /// - SeeAlso: ``RepositoryPagedResult``, ``PageToken``, and ``list(userId:)``.
    func listPaginated(userId: String, pageSize: Int, pageToken: String?)
        async throws -> RepositoryPagedResult<Todo>

    /// Updates a todo's properties with the provided values for the specified user.
    ///
    /// Only non-nil parameters are updated. For example, if `title` is `nil`,
    /// the existing title is preserved.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todo is being updated.
    ///   - id: The UUID of the todo to update.
    ///   - title: A new title for the todo, or `nil` to keep the existing title.
    ///   - order: A new order value, or `nil` to keep the existing order.
    ///   - completed: A new completion status, or `nil` to keep the existing status.
    ///
    /// - Returns: The updated `Todo` if the update succeeded, or `nil` if no todo
    ///   with the provided ID exists for the specified user.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    func update(userId: String, id: UUID, title: String?, order: Int?, completed: Bool?)
        async throws -> Todo?

    /// Deletes a single todo by its unique identifier for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todo is being deleted.
    ///   - id: The UUID of the todo to delete.
    ///
    /// - Returns: `true` if the deletion succeeded, `false` if no todo with that ID exists for the specified user.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    func delete(userId: String, id: UUID) async throws -> Bool

    /// Deletes all todos for the specified user from storage.
    ///
    /// This is a destructive operation that removes every todo for the given user.
    /// Use with caution in production environments.
    ///
    /// - Parameter userId: The unique identifier of the authenticated user whose todos are being deleted.
    ///
    /// - Returns: `true` if the deletion succeeded, `false` otherwise.
    ///
    /// - Throws: Any errors from the underlying storage implementation.
    func deleteAll(userId: String) async throws -> Bool
}
