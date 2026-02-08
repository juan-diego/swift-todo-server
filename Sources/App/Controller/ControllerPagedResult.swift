import Hummingbird

/// A generic adapter for paginated results used in HTTP responses.
///
/// `ControllerPagedResult` conforms to ``PagedResult`` and `ResponseEncodable`, allowing it to be returned directly from controller route handlers.
/// It can be constructed from item arrays or from any existing ``PagedResult`` source, making it a convenient bridge between repository/model layers and HTTP responses.
///
/// - Parameters:
///   - Item: The element type in the `items` array. Must conform to `Codable`.
///
/// - SeeAlso: ``PagedResult``
struct ControllerPagedResult<Item: Codable> : ResponseEncodable, PagedResult {
    /// The items included in this page.
    let items: [Item]
    /// The token for the next page, if any.
    let nextPageToken: String?
    
    /// Initializes a `ControllerPagedResult` with a list of items and no next page token.
    /// - Parameter items: The items to include in this page.
    /// - Note: `nextPageToken` will be `nil`. Typically used when all results are returned in a single page.
    init(from items: [Item]) {
        self.items = items
        self.nextPageToken = nil
    }
    
    /// Initializes a `ControllerPagedResult` by copying items and pagination token from another `PagedResult`.
    /// - Parameter pageResult: Any value conforming to `PagedResult` with the same `Item` type.
    /// - Note: This is a convenience initializer for adapting repository/result types to controller responses.
    init<SourcePagedResult: PagedResult>(from pageResult: SourcePagedResult) where SourcePagedResult.Item == Item {
        self.items = pageResult.items
        self.nextPageToken = pageResult.nextPageToken
    }
}
