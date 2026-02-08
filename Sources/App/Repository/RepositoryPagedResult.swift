import Foundation

/// A generic container for paginated query results from a repository or data source.
///
/// `RepositoryPagedResult` conforms to ``PagedResult`` and is typically used to represent a page of items and an opaque pagination token.
/// It is often used by repository or service layers to encapsulate one page of results for a given query.
///
/// - Parameters:
///   - Item: The type of each item. Must conform to both `Codable` and `Sendable` for compatibility with async concurrency and serialization.
///
/// - SeeAlso: ``PagedResult``
struct RepositoryPagedResult<Item: Codable & Sendable> : PagedResult {
    let items: [Item]
    let nextPageToken: String?
}

