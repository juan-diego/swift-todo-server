import Foundation
import Logging

/// A Firestore-backed implementation of the ``TodoRepository`` protocol.
///
/// `TodoFirestoreRepository` provides persistent todo storage using Google Cloud Firestore.
/// It communicates with Firestore via the REST API, supporting both production GCP environments
/// and local Firestore emulator instances.
///
/// ## Architecture
///
/// The repository follows a layered architecture:
///
/// ```
/// TodoFirestoreRepository (this actor)
///          ↓ uses
/// FirestoreHTTPClient (REST API communication)
///          ↓ uses
/// URLSession (HTTP networking)
///          ↓ uses
/// Firestore REST API (production or emulator)
/// ```
///
/// ## Features
///
/// - **Persistent Storage**: All todos are stored in Firestore and survive application restarts
/// - **Per-User Filtering**: All queries filter todos by their ownerId matching the userId
/// - **Cursor-Based Pagination**: Efficient pagination using Firestore's native pagination tokens
/// - **Batch Operations**: Optimized batch deletion with concurrent task execution
/// - **Error Recovery**: Graceful handling of network errors and Firestore API failures
/// - **Logging**: Comprehensive logging at configurable levels for debugging and monitoring
///
/// ## Authentication & Deployment
///
/// ### Production (Google Cloud)
/// Authenticates via the GCP Metadata Service (automatic on Cloud Run, Compute Engine, etc.)
///
/// ### Development/Testing
/// Uses the Firestore emulator without authentication
///
/// ## Collection Structure
///
/// Todos are stored in the `todos` collection with this structure:
///
/// ```
/// projects/{projectId}/databases/(default)/documents/todos/{documentId}
/// {
///   "name": "projects/my-project/databases/(default)/documents/todos/550e8400-...",
///   "fields": {
///     "id": { "stringValue": "550e8400-e29b-41d4-a716-446655440000" },
///     "title": { "stringValue": "Buy groceries" },
///     "url": { "stringValue": "http://localhost:8080/todos/550e8400-..." },
///     "order": { "integerValue": "1" },
///     "completed": { "booleanValue": true },
///     "ownerId": { "stringValue": "<userId>" }
///   },
///   "createTime": "2024-01-15T10:30:00Z",
///   "updateTime": "2024-01-15T10:35:00Z"
/// }
/// ```
///
/// ## Concurrency & Thread Safety
///
/// This class is an actor, ensuring all access is serialized and safe across concurrent tasks.
/// Multiple tasks can call any method without additional synchronization.
///
/// ## Error Handling
///
/// The repository handles errors at multiple levels:
///
/// 1. **HTTP Errors**: Captured by ``FirestoreHTTPClient``
/// 2. **Parsing Errors**: When deserializing Firestore responses
/// 3. **Not Found**: Gracefully returns `nil` for missing documents or owner mismatch
/// 4. **Network Errors**: Propagated for caller to handle
///
/// ## Performance Considerations
///
/// - **Cost Model**: Each CRUD operation counts as 1 read/write operation
/// - **Batch Deletion**: Uses concurrent tasks to delete multiple todos in parallel
/// - **Pagination**: Efficient O(pageSize) performance for large datasets
/// - **Latency**: Network latency is the primary performance bottleneck (~50-200ms per request)
///
/// - SeeAlso: ``FirestoreHTTPClient``, ``FirestoreConfig``
actor TodoFirestoreRepository: TodoRepository {

    /// HTTP client for communicating with Firestore REST API.
    private let httpClient: FirestoreHTTPClient

    /// Configuration containing project ID and API endpoint.
    private let config: FirestoreConfig

    /// Full Firestore collection path for todos.
    ///
    /// Format: `/projects/{projectId}/databases/(default)/documents/todos`
    private let endpoint: String

    /// Logging level for repository-level operational logs.
    private let logLevel: Logger.Level

    /// Logger for debugging and monitoring repository operations.
    private let logger = Logger(label: "TodoFirestoreRepository")

    /// Initializes a new Firestore todo repository.
    ///
    /// ## Parameters
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for Firestore API communication
    ///   - config: Firestore configuration with project ID and API endpoint
    ///   - logLevel: Logging level for repository operations (default: `.info`)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = FirestoreConfig(projectId: "my-project")
    /// let tokenProvider = MetadataServerAccessTokenProvider()
    /// let httpClient = FirestoreHTTPClient(config: config, tokenProvider: tokenProvider)
    /// let repository = TodoFirestoreRepository(
    ///     httpClient: httpClient,
    ///     config: config,
    ///     logLevel: .debug
    /// )
    /// ```
    ///
    /// ## Notes
    ///
    /// - The logger label is always `"TodoFirestoreRepository"` for consistency
    /// - The endpoint path is constructed from the project ID in config
    /// - No validation is performed on the HTTP client or config at initialization time
    init(
        httpClient: FirestoreHTTPClient,
        config: FirestoreConfig,
        logLevel: Logger.Level = .info
    ) {
        self.httpClient = httpClient
        self.config = config
        self.endpoint =
            "/projects/\(config.projectId)/databases/(default)/documents/todos"
        self.logLevel = logLevel
    }

    // MARK: - List Todos (filtered by userId)

    /// Retrieves all todos for the specified user from Firestore.
    ///
    /// This method fetches all documents from the todos collection that belong to the user,
    /// using Firestore's structured query API and filtering by ownerId == userId.
    ///
    /// This is suitable for small to medium datasets per user.
    ///
    /// - Parameter userId: The user ID to filter todos by (ownerId)
    ///
    /// - Returns: Array of all todos for the user. Returns an empty array if no todos exist.
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func list(userId: String) async throws -> [Todo] {
        // Firestore :runQuery endpoint path
        let runQueryPath = "/projects/\(config.projectId)/databases/(default)/documents:runQuery"
        
        // Build structured query without limit to return all matching documents.
        let body = buildStructuredQuery(ownerId: userId)
        
        // `runQuery` returns an array of result entries.
        // Each entry has a "document" or "skippedResults" etc.
        let responseData: [FirestoreRunQueryResponseEntry] = try await httpClient.send(
            method: "POST",
            path: runQueryPath,
            body: body
        )
        
        // Extract documents and convert to Todo, filtering by ownerId (defensive)
        var todos = [Todo]()
        for entry in responseData {
            if let doc = entry.document, let todo = try? Todo(from: doc), doc.ownerId == userId {
                todos.append(todo)
            }
        }
        return todos
    }

    /// Retrieves a paginated list of todos for the user using cursor-based pagination.
    ///
    /// This method implements efficient, cursor-based pagination suitable for large
    /// user-specific result sets. Cursor-based pagination provides consistent performance regardless
    /// of the page position and handles concurrent modifications more gracefully than
    /// offset-based approaches.
    ///
    /// - Note: The returned value is a ``RepositoryPagedResult`` (conforming to ``PagedResult``), which provides access to the page's items and an optional pagination token. Consumers can handle pagination generically via the `PagedResult` protocol.
    ///
    /// - Parameters:
    ///   - userId: The user ID to filter todos by (ownerId)
    ///   - pageSize: The maximum number of todos to return (1-100).
    ///     Defaults to 10. Values outside this range are clamped.
    ///   - pageToken: Optional pagination token from a previous response.
    ///     Pass `nil` to start from the beginning. The token should be a JSON-encoded array string of cursor values.
    ///
    /// - Returns: A `RepositoryPagedResult` object containing:
    ///   - `items`: Array of todos for this page
    ///   - `nextPageToken`: Token for fetching the next page, or `nil` if this is the last page
    ///
    /// This encapsulates the page data in a single value rather than a tuple,
    /// facilitating cleaner and more extensible pagination handling.
    ///
    /// Clients should read the properties like so:
    /// ```swift
    /// let page = try await repository.listPaginated(userId: "user123", pageSize: 10, pageToken: nil)
    /// let todos = page.items
    /// let nextToken = page.nextPageToken
    /// ```
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    ///
    /// - SeeAlso: ``RepositoryPagedResult``, ``PageToken``
    func listPaginated(
        userId: String,
        pageSize: Int = 10,
        pageToken: String? = nil
    ) async throws -> RepositoryPagedResult<Todo> {
        let validPageSize = max(1, min(pageSize, 100))
        let runQueryPath = "/projects/\(config.projectId)/databases/(default)/documents:runQuery"

        let body = buildStructuredQuery(
            ownerId: userId,
            pageSize: validPageSize,
            pageToken: pageToken
        )

        let responseEntries: [FirestoreRunQueryResponseEntry] = try await httpClient.send(
            method: "POST",
            path: runQueryPath,
            body: body
        )

        var todos = [Todo]()
        var lastDocumentName: String?
        for entry in responseEntries {
            if let doc = entry.document, let todo = try? Todo(from: doc), doc.ownerId == userId {
                todos.append(todo)
                lastDocumentName = doc.name
            }
        }

        // Firestore does not return nextPageToken for runQuery.
        // We simulate nextPageToken by encoding the last document's order and __name__ fields as cursor values.
        // The cursor order fields are: ["order" field, "__name__" field] per the orderBy clause.

        // If fewer items than pageSize, no next page
        if todos.count < validPageSize {
            return RepositoryPagedResult(items: todos, nextPageToken: nil)
        }

        guard let lastTodo = todos.last else {
            return RepositoryPagedResult(items: [], nextPageToken: nil)
        }

        // Encode cursorValues as JSON string for nextPageToken
        // "order" (integerValue) and "__name__" (stringValue)
        // "__name__" is the full document name string.
        let nextPageToken = FirestoreTodoPageToken.encode(order: lastTodo.order, documentName: lastDocumentName)

        return RepositoryPagedResult(items: todos, nextPageToken: nextPageToken)
    }

    // MARK: - Get, Update, Delete with ownerId check

    /// Retrieves a single todo by its unique identifier and verifies ownership.
    ///
    /// - Parameters:
    ///   - userId: The user ID to verify ownership
    ///   - id: The UUID of the todo to retrieve
    ///
    /// - Returns: The ``Todo`` if found and owned by userId, or `nil` if no todo found or ownership mismatch
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func get(userId: String, id: UUID) async throws -> Todo? {
        let path = "\(endpoint)/\(id.uuidString)"
        return try await submitRequest {
            let document: FirestoreTodoDocument = try await httpClient.send(
                method: "GET",
                path: path
            )
            
            let todo = try Todo(from: document)
            
            // Verify ownership
            if document.ownerId == userId {
                return todo
            } else {
                return nil
            }
        }
    }

    /// Creates a new todo in Firestore.
    ///
    /// This method creates a new todo document with a generated UUID and stores it in Firestore.
    /// The document ID is the todo's UUID, allowing for efficient direct lookups.
    ///
    /// ## Behavior
    ///
    /// - Generates a new UUID for the todo
    /// - Sets `completed` to `false` by default
    /// - Constructs the full URL for accessing this todo
    /// - Returns the created todo with all fields populated
    ///
    /// ## Performance
    ///
    /// - **Network Cost**: 1 write operation
    /// - **Latency**: ~50-200ms (network dependent)
    /// - **Time Complexity**: O(1)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let newTodo = try await repository.create(
    ///     userId: "user123",
    ///     title: "Buy groceries",
    ///     order: 1,
    ///     urlPrefix: "http://localhost:8080/todos/"
    /// )
    ///
    /// print("Created todo: \(newTodo.id)")
    /// print("Access at: \(newTodo.url)")
    /// ```
    ///
    /// - Parameters:
    ///   - userId: The user ID that will own the new todo.
    ///   - title: The human-readable task description
    ///   - order: Optional integer for sorting todos in lists
    ///   - urlPrefix: Base URL path (e.g., `http://localhost:8080/todos/`) to which the UUID is appended
    ///
    /// - Returns: The newly created ``Todo`` with generated UUID and populated URL
    ///
    /// - Throws:
    ///   - ``FirestoreHTTPError.unauthorized``: If authentication fails
    ///   - ``FirestoreHTTPError.serverError``: If Firestore returns an error
    ///   - ``FirestoreHTTPError.encodingError``: If the todo cannot be serialized to Firestore format
    ///   - ``FirestoreHTTPError.decodingError``: If the response cannot be parsed
    ///
    /// - SeeAlso: ``update(id:title:order:completed:)`` to modify existing todos
    func create(userId: String, title: String, order: Int?, urlPrefix: String) async throws
        -> Todo
    {
        let id = UUID()
        let url = urlPrefix + id.uuidString
        let todo = Todo(
            id: id,
            title: title,
            order: order ?? 0,
            url: url,
            completed: false
        )
        let firestoreDoc = FirestoreTodoDocument(from: todo, withOwnerId: userId)
        let queryItems = [
            URLQueryItem(name: "documentId", value: todo.id.uuidString)
        ]
        let created: FirestoreTodoDocument = try await httpClient.send(
            method: "POST",
            path: endpoint,
            queryItems: queryItems,
            body: firestoreDoc
        )
        return try Todo(from: created)
    }

    /// Updates a todo's properties in Firestore, verifying ownership.
    ///
    /// - Parameters:
    ///   - userId: The user ID to verify ownership
    ///   - id: The UUID of the todo to update
    ///   - title: New title for the todo, or `nil` to keep the existing title
    ///   - order: New order value, or `nil` to keep the existing order
    ///   - completed: New completion status, or `nil` to keep the existing status
    ///
    /// - Returns: The updated ``Todo`` if ownership is verified, or `nil` if not found or ownership mismatch
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func update(userId: String, id: UUID, title: String?, order: Int?, completed: Bool?)
        async throws -> Todo?
    {
        // Get and update
        guard var todo = try await get(userId: userId, id: id) else {
            return nil
        }
        if let title {
            todo.title = title
        }
        if let order {
            todo.order = order
        }
        if let completed {
            todo.completed = completed
        }
        // Patch
        let path = "\(endpoint)/\(todo.id.uuidString)"
        let firestoreDoc = FirestoreTodoDocument(from: todo, withOwnerId: userId)
        return try await submitRequest {
            let updated: FirestoreTodoDocument = try await httpClient.send(
                method: "PATCH",
                path: path,
                body: firestoreDoc
            )
            let updatedTodo = try Todo(from: updated)
            // Verify ownership after update
            if updated.ownerId == userId {
                return updatedTodo
            } else {
                return nil
            }
        }
    }

    /// Deletes a single todo from Firestore after verifying ownership.
    ///
    /// - Parameters:
    ///   - userId: The user ID to verify ownership
    ///   - id: The UUID of the todo to delete
    ///
    /// - Returns: `true` if the deletion succeeded and ownership verified, `false` otherwise
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func delete(userId: String, id: UUID) async throws -> Bool {
        // Verify ownership before deletion
        guard let todo = try await get(userId: userId, id: id) else {
            // Not found or ownership mismatch: treat as success for idempotency
            return true
        }
        let path: String = "\(endpoint)/\(todo.id.uuidString)"
        let result = try await submitRequest {
            struct EmptyResponse: Decodable, Sendable {}
            let _: EmptyResponse = try await httpClient.send(
                method: "DELETE",
                path: path
            )
            return true
        }
        return result ?? false
    }

    // MARK: - Delete multiple todos (with ownership check via get in delete)

    /// Deletes multiple todos from Firestore using concurrent operations.
    ///
    /// - Parameters:
    ///   - userId: The user ID to verify ownership for each delete.
    ///   - todos: Array of todos to delete.
    ///
    /// - Returns: `true` if all deletions succeeded, `false` if any deletion failed
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func delete(userId: String, todos: [Todo]) async throws -> Bool {
        if todos.isEmpty {
            return true
        }

        return await withTaskGroup(of: Bool.self) { group in
            for todo in todos {
                group.addTask {
                    do {
                        return try await self.delete(userId: userId, id: todo.id)
                    } catch {
                        return false
                    }
                }
            }

            var countSuccess = 0
            for await deleted in group {
                if deleted {
                    countSuccess += 1
                }
            }

            logger.log(
                level: logLevel,
                "Deleted \(countSuccess) of \(todos.count) todos."
            )
            return countSuccess == todos.count
        }
    }

    /// Deletes all todos from Firestore for the given user.
    ///
    /// This method removes all todo documents from the collection belonging to the user,
    /// using an efficient pagination-based approach and concurrent deletion.
    ///
    /// - Parameter userId: The user ID to filter todos by (ownerId)
    ///
    /// - Returns: `true` if all todos were successfully deleted, `false` otherwise
    ///
    /// - Throws: See underlying FirestoreHTTPClient.send for various HTTP errors.
    func deleteAll(userId: String) async throws -> Bool {
        // Fetch all todos for the user before deleting
        let todos = try await list(userId: userId)
        if todos.isEmpty {
            return true
        }

        // Batch delete using pagination and concurrency
        var pageToken: String? = nil
        repeat {
            let page = try await listPaginated(
                userId: userId,
                pageSize: 10,
                pageToken: pageToken
            )
            if !(try await delete(userId: userId, todos: todos)) {
                return false
            }
            pageToken = page.nextPageToken
        } while pageToken != nil

        return true
    }
    
    // MARK: - Structured Query Helpers

    /// Builds a structured query dictionary to filter todos by ownerId with optional pagination.
    /// Used for Firestore :runQuery endpoint POST body.
    ///
    /// - Parameters:
    ///   - ownerId: The userId to filter by (ownerId == userId)
    ///   - pageSize: Number of documents to return (optional)
    ///   - pageToken: Cursor for pagination (optional)
    ///
    /// - Returns: Dictionary representing the Firestore structuredQuery request body.
    private func buildStructuredQuery(
        ownerId: String,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) -> FirestoreStructuredQueryRequest {
        let orderBys: [FirestoreStructuredQueryRequest.OrderBy] = [
            .init(field: .init(fieldPath: "order"), direction: "ASCENDING"),
            .init(field: .init(fieldPath: "__name__"), direction: "ASCENDING")
        ]
        let from: [FirestoreStructuredQueryRequest.From] = [
            .init(collectionId: "todos")
        ]
        let whereClause = FirestoreStructuredQueryRequest.Where(
            fieldFilter: .init(
                field: .init(fieldPath: "ownerId"),
                op: "EQUAL",
                value: .init(stringValue: ownerId)
            )
        )
        
        let structuredQuery = FirestoreStructuredQueryRequest.StructuredQuery(
            from: from,
            whereClause: whereClause,
            orderBy: orderBys,
            limit: pageSize,
            startAt: FirestoreTodoPageToken.decode(pageToken)
        )
        return FirestoreStructuredQueryRequest(structuredQuery: structuredQuery)
    }

    /// Wraps a Firestore request to handle "not found" errors gracefully.
    ///
    /// This helper method executes a Firestore API call and handles the special case
    /// where a document is not found. Instead of propagating the error, it returns `nil`
    /// to match the protocol's behavior of returning optional values for missing items.
    ///
    /// - Parameter submitClosure: Async closure that performs the Firestore operation
    ///
    /// - Returns: The closure's return value, or `nil` if a "not found" error occurs
    ///
    /// - Throws: Any error except "not found" (which is converted to nil)
    private func submitRequest<Document>(_ submitClosure: () async throws -> Document?) async throws -> Document? {
        do {
            return try await submitClosure()
        } catch let error as FirestoreHTTPError {
            if case .notFound = error {
                return nil
            }
            throw error
        }
    }
}

// MARK: - FirestoreTodoDocument Extension

extension FirestoreTodoDocument {
    /// Extracts the owner ID from the document fields.
    var ownerId: String? {
        if case let .string(idString) = fields.ownerId {
            return idString
        } else {
            return nil
        }
    }
}

// MARK: - FirestoreTodoPageToken Extension

extension FirestoreTodoPageToken {
    /// Encodes Firestore cursor values into an opaque pagination token.
    ///
    /// - Parameters:
    ///   - order: The last item's order value.
    ///   - documentName: The last item's full Firestore document name.
    /// - Returns: A base64-encoded pagination token, or `nil` if required values are missing.
    static func encode(order: Int?, documentName: String?) -> String? {
        guard let order, let documentName else { return nil }
        return self.init(cursor: QueryCursor(order: order, documentName: documentName)).pageToken
    }
    
    /// Decodes an opaque pagination token into Firestore `startAt` values.
    ///
    /// - Parameter pageToken: The token to decode.
    /// - Returns: A Firestore `startAt` cursor or `nil` if the token is missing or invalid.
    static func decode(_ pageToken: String?) -> FirestoreStructuredQueryRequest.StartAt? {
        guard let pageToken, let decodedToken = self.init(pageToken: pageToken) else {
            return nil
        }
        
        let values = [
            FirestoreStructuredQueryRequest.Value(integerValue: String(decodedToken.cursor.order)),
            FirestoreStructuredQueryRequest.Value(referenceValue: decodedToken.cursor.documentName)
        ]
        return FirestoreStructuredQueryRequest.StartAt.init(values: values, before: false)
    }
}
