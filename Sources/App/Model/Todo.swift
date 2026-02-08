import Foundation
import Hummingbird

/// A todo item in the todo list.
///
/// `Todo` represents a single task that can be created, read, updated, and deleted.
/// The struct is designed to work seamlessly with both HTTP responses and persistence layers.
///
/// ## Properties
///
/// - `id`: Unique identifier for the todo, used in URLs and database lookups
/// - `title`: Human-readable name of the task
/// - `order`: Optional sorting hint to maintain task order in lists
/// - `url`: Full URL path for accessing this todo via the API (e.g., `/todos/12345-abc`)
/// - `completed`: Optional flag indicating whether the task is finished
///
/// ## Encoding and Decoding
///
/// `Todo` conforms to `Decodable` for parsing JSON request bodies and `ResponseEncodable`
/// for serializing responses back to JSON. This allows Hummingbird to automatically handle
/// serialization in route handlers.
struct Todo {
    /// Unique identifier for this todo.
    ///
    /// Generated as a UUID v4 when the todo is created.
    var id: UUID

    /// The user-visible title or description of the task.
    var title: String

    /// Optional integer for maintaining the order of todos in a list.
    ///
    /// Useful for UI layouts where todos should appear in a specific sequence.
    var order: Int?

    /// The full URL path for accessing this todo via the API.
    ///
    /// Example: `http://localhost:8080/todos/550e8400-e29b-41d4-a716-446655440000`
    ///
    /// This is typically set during todo creation by the ``TodoRepository``.
    var url: String

    /// Optional completion status of the todo.
    ///
    /// `true` indicates the task is complete, `false` indicates it's pending,
    /// and `nil` represents an unset state (often treated as `false`).
    var completed: Bool?
}

/// Conformances for serialization and HTTP response encoding.
///
/// - `ResponseEncodable`: Allows Hummingbird to serialize `Todo` instances as JSON responses
/// - `Decodable`: Allows Hummingbird to parse JSON request bodies into `Todo` instances
/// - `Equatable`: Enables comparison and testing of `Todo` values
extension Todo: ResponseEncodable, Decodable, Equatable {}
