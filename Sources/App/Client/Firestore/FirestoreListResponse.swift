/// A generic response wrapper for Firestore list operations that return multiple documents.
///
/// `FirestoreListResponse` represents the JSON structure returned by Firestore's REST API
/// when querying a collection. It provides type-safe access to the returned documents
/// and supports pagination through a token-based mechanism.
///
/// This struct is generic over a `Document` type, which must conform to `Codable` and `Sendable`,
/// allowing flexible use with various Firestore document models.
///
/// ## Firestore API Response Format
///
/// Firestore returns list responses with the following JSON structure:
/// ```json
/// {
///   "documents": [
///     { "name": "...", "fields": { ... } },
///     { "name": "...", "fields": { ... } }
///   ],
///   "nextPageToken": "some-token-for-next-page"
/// }
/// ```
///
/// - Note:
///   - The `documents` array is optional and may be omitted if no documents match the query.
///   - The `nextPageToken` is optional and indicates whether more pages of results are available.
///
/// - Parameter Document: The type of documents included in the response, conforming to `Codable` and `Sendable`.
struct FirestoreListResponse<Document: Codable & Sendable>: Codable, Sendable {
    /// An optional array of documents returned by the Firestore query.
    ///
    /// - When present, contains zero or more documents matching the query.
    /// - When `nil`, indicates that no documents were returned or the field was omitted in the response.
    var documents: [Document]?

    /// An optional token to retrieve the next page of query results.
    ///
    /// - When non-`nil`, this token should be used as a query parameter in a subsequent request
    ///   to fetch the next batch of documents.
    /// - When `nil`, indicates that there are no additional pages and all results have been returned.
    var nextPageToken: String?
}
