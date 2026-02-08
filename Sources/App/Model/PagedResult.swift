/// A protocol describing types that represent paginated query results.
///
/// Types conforming to `PagedResult` provide a collection of items and an optional pagination token (`nextPageToken`).
/// The protocol is generic over the `Item` type, which must conform to `Codable`.
///
/// Use this protocol for APIs that return a subset of all possible results, along with a token to fetch the next page.
/// Conforming types can be used for cursor-based, offset-based, or any other pagination strategy.
///
/// - Note: The protocol requires conformance to `Codable` for interoperability with HTTP APIs, JSON, or other data formats.
///
/// Example implementation:
/// ```swift
/// struct TodosPage: PagedResult {
///     let items: [Todo]
///     let nextPageToken: String?
/// }
/// ```
protocol PagedResult : Codable {
    /// The item type contained in the page.
    associatedtype Item: Codable
    
    /// The items contained in this page.
    var items: [Item] { get }
    
    /// The opaque token for fetching the next page, if any.
    var nextPageToken: String? { get }
}

extension PagedResult {
    /// Indicates whether the result contains a next page token.
    var hasMoreElements: Bool {
        return nextPageToken != nil
    }
}
