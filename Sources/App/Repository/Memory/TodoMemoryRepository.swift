import Foundation

/// Errors that can occur during in-memory repository operations.
enum MemoryRepositoryError: Error, Sendable {
    /// The pagination token is invalid or malformed.
    ///
    /// This typically occurs when a token from a previous pagination request
    /// cannot be decoded or contains invalid data.
    case invalidPageToken
}

/// An in-memory implementation of ``TodoRepository`` using a Swift dictionary.
///
/// `TodoMemoryRepository` stores all todos in memory and loses all data when the
/// application terminates. It's implemented as an actor, making all operations
/// automatically serialized and safe across concurrent tasks.
///
/// All operations act only on todos belonging to a specific authenticated user, identified by the required `userId` parameter.
///
/// ## Use Cases
///
/// - Development and testing without database setup
/// - Demos and quick prototypes
/// - Debugging route handlers
/// - Unit tests that don't require persistence
///
/// ## Performance Characteristics
///
/// - All operations are O(1) dictionary lookups and insertions scoped to the user
/// - No network latency or blocking I/O
/// - Memory usage grows linearly with the number of todos per user
/// - Perfect for testing with manageable data volumes
///
/// ## Thread Safety
///
/// This actor automatically serializes all access. Multiple concurrent tasks can safely
/// call any method without additional synchronization.
actor TodoMemoryRepository: TodoRepository {
    /// A dictionary mapping UUID to Todo, acting as the in-memory storage.
    private var todos: [String:[UUID: Todo]]

    /// Initializes an empty in-memory repository.
    init() {
        self.todos = [:]
    }

    /// Creates a new todo in memory for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - title: The task description
    ///   - order: Optional sorting value
    ///   - urlPrefix: Base URL to which the UUID will be appended
    ///
    /// - Returns: The newly created todo with a fresh UUID
    func create(
        userId: String,
        title: String,
        order: Int?,
        urlPrefix: String
    ) async throws -> Todo {
        let id = UUID()
        let url = urlPrefix + id.uuidString
        let todo = Todo(
            id: id,
            title: title,
            order: order,
            url: url,
            completed: false
        )
        if self.todos[userId] == nil {
            self.todos[userId] = [id: todo]
        }
        else {
            self.todos[userId]?[id] = todo
        }
        return todo
    }

    /// Retrieves a todo by ID for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - id: The UUID to look up
    ///
    /// - Returns: The matching todo belonging to the user, or `nil` if not found
    func get(userId: String, id: UUID) async throws -> Todo? {
        return self.todos[userId]?[id]
    }

    /// Retrieves all todos for the specified user.
    ///
    /// - Parameter userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///
    /// - Returns: An array of all stored todos for the user (empty if none exist)
    func list(userId: String) async throws -> [Todo] {
        if let userTodos = self.todos[userId] {
            userTodos.values.map { $0 }
        } else {
            []
        }
    }

    /// Retrieves a paginated list of todos for the specified user using offset-based pagination.
    ///
    /// This method simulates cursor-based pagination for consistency with the Firestore
    /// implementation, but uses offset internally for the in-memory dictionary.
    ///
    /// - Note: The returned value is a ``RepositoryPagedResult`` (conforming to ``PagedResult``), providing both the items and a pagination token. This enables generic handling of paginated results across repository implementations.
    ///
    /// ## How Pagination Works
    ///
    /// 1. First request: Call with `pageToken: nil` to get the first page
    /// 2. Response includes a ``RepositoryPagedResult`` object containing:
    ///    - `items`: The array of todos for this page
    ///    - `nextPageToken`: Token for fetching the next page, or `nil` if this is the last page
    /// 3. Subsequent requests: Use the returned `nextPageToken` for the next page
    /// 4. Stop when `nextPageToken` is `nil` (reached the end)
    ///
    /// ## Example Usage
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
    /// ## Performance Characteristics
    ///
    /// - Time complexity: O(pageSize) for in-memory operations
    /// - Suitable for: Development, testing, small datasets
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - pageSize: The maximum number of todos to return (1-100).
    ///     Defaults to 10. Values outside this range are clamped.
    ///   - pageToken: Optional pagination token from a previous response.
    ///     Pass `nil` to start from the beginning.
    ///     The token encodes the offset for the next page.
    ///
    /// - Returns: A ``RepositoryPagedResult`` instance containing:
    ///   - `items`: Array of todos for this page (may be less than pageSize if near the end)
    ///   - `nextPageToken`: Token for fetching the next page, or `nil` if this is the last page
    ///
    /// - Note: This implementation uses offset-based pagination internally.
    ///   Tokens are base64-encoded offset values wrapped in a ``PageToken`` type.
    ///
    /// - SeeAlso: ``list(userId:)`` for retrieving all todos at once
    func listPaginated(
        userId: String,
        pageSize: Int = 10,
        pageToken: String? = nil
    ) async throws -> RepositoryPagedResult<Todo> {
        // Check if the user has todos
        guard let userTodos = self.todos[userId] else {
            return RepositoryPagedResult(items: [], nextPageToken: nil)
        }
        
        // Clamp pageSize to valid range
        let validPageSize = max(1, min(pageSize, 100))

        // Decode pageToken to get the starting offset
        let offset = try MemoryTodoPageToken.decode(pageToken)

        let allTodos = Array(userTodos.values)

        // Return empty result if offset is beyond available items
        guard offset < allTodos.count else {
            return RepositoryPagedResult(items: [], nextPageToken: nil)
        }

        // Get the slice for this page
        let endIndex = min(offset + validPageSize, allTodos.count)
        let pageItems = Array(allTodos[offset..<endIndex])

        // Generate next page token if there are more results
        let nextPageToken = MemoryTodoPageToken.encode(index: endIndex, totalOfItems: allTodos.count)

        return RepositoryPagedResult(items: pageItems, nextPageToken: nextPageToken)
    }

    /// Updates a todo's fields for the specified user.
    ///
    /// Only non-nil parameters are applied to the existing todo.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - id: The todo to update
    ///   - title: New title, or `nil` to keep existing
    ///   - order: New order, or `nil` to keep existing
    ///   - completed: New completion status, or `nil` to keep existing
    ///
    /// - Returns: The updated todo for the user, or `nil` if not found
    func update(userId: String, id: UUID, title: String?, order: Int?, completed: Bool?)
        async throws -> Todo?
    {
        if var todo = self.todos[userId]?[id] {
            if let title {
                todo.title = title
            }
            if let order {
                todo.order = order
            }
            if let completed {
                todo.completed = completed
            }
            self.todos[userId]?[id] = todo
            return todo
        }
        return nil
    }

    /// Deletes a single todo by ID for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///   - id: The UUID of the todo to delete
    ///
    /// - Returns: `true` if deleted, `false` if not found
    func delete(userId: String, id: UUID) async throws -> Bool {
        if self.todos[userId]?[id] != nil {
            self.todos[userId]?[id] = nil
            return true
        }
        return false
    }

    /// Deletes all todos from memory for the specified user.
    ///
    /// This is a destructive operation. All todos belonging to the user are removed immediately.
    ///
    /// - Parameter userId: The unique identifier of the authenticated user whose todos are affected by this operation.
    ///
    /// - Returns: Always returns `true`
    func deleteAll(userId: String) async throws -> Bool {
        self.todos[userId] = nil
        return true
    }
}

// MARK: - MemoryTodoPageToken Extension

extension MemoryTodoPageToken {
    /// Decodes a pagination token into an integer offset.
    ///
    /// - Parameter pageToken: The base64-encoded token string.
    /// - Returns: The decoded offset, or 0 when the token is `nil`.
    /// - Throws: ``MemoryRepositoryError.invalidPageToken`` if decoding fails.
    static func decode(_ pageToken: String?) throws -> Int {
        if let token = pageToken {
            guard let decodedPageToken = Self.init(pageToken: token) else {
                throw MemoryRepositoryError.invalidPageToken
            }
            return decodedPageToken.cursor
        } else {
            return 0
        }
    }
    
    /// Encodes the next offset into a pagination token, if more items remain.
    ///
    /// - Parameters:
    ///   - index: The next offset to encode.
    ///   - totalOfItems: The total number of items in the dataset.
    /// - Returns: A base64-encoded token string, or `nil` if there is no next page.
    static func encode(index: Int, totalOfItems: Int) -> String? {
        (index < totalOfItems) ? self.init(cursor: index).pageToken : nil
    }
}
