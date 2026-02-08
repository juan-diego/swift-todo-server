/// Protocol for cursor-based pagination tokens.
///
/// `PageToken` defines a standardized interface for encoding and decoding cursor-based pagination tokens. Conforming types
/// enable consistent and type-safe handling of pagination tokens in asynchronous paginated queries, such as those used in repositories.
///
/// The protocol is generic over two associated types:
/// - `Cursor`: The type representing the decoded cursor value used for pagination (e.g., struct, tuple, or simple value).
/// - `Token`: The type used to transmit the encoded token, typically `String` for API use.
///
/// Implementations must provide initializers for decoding a token and for constructing a token from a cursor value, as well as computed properties for extracting the cursor and encoded token.
///
/// ### Example
/// ```swift
/// struct ExamplePageToken: PageToken {
///     struct Cursor { let id: Int }
///     typealias Token = String
///     let cursor: Cursor
///     var pageToken: Token? { /* encode cursor */ }
///     init(cursor: Cursor) { self.cursor = cursor }
///     init?(pageToken: Token) { /* decode token */ }
/// }
/// ```
///
/// - SeeAlso: ``RepositoryPagedResult``, ``TodoRepository``
protocol PageToken {
    /// The decoded cursor value representing the pagination state.
    associatedtype Cursor
    
    /// The encoded token type (typically `String`).
    associatedtype Token
    
    /// Initializes a new token from the underlying cursor value.
    /// - Parameter cursor: The cursor value representing page state.
    init(cursor: Cursor)
    
    /// Attempts to initialize a token from the encoded representation.
    /// - Parameter pageToken: The encoded token value (e.g., base64 string).
    /// - Returns: An instance if decoding succeeds, or `nil` if invalid.
    init?(pageToken: Token)
    
    /// The underlying cursor value for this token.
    var cursor: Cursor { get }
    
    /// The encoded token representation for use in API requests.
    var pageToken: Token? { get }
}
